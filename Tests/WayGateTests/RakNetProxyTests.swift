import RakNet
import Testing
import WayGate

@Test(.timeLimit(.minutes(1))) func proxyRelaysRakNetPayloadsInBothDirections() async throws {
    let loopback = RakNetEndpoint.ipv4(IPv4Endpoint(address: 0x7f000001, port: 0))
    let backend = try RakNetListener.listen(on: loopback)
    defer { backend.close() }
    let proxy = try RakNetProxy(on: loopback, upstream: backend.localAddress, advertisement: [42])
    let forwarding = Task { try await proxy.run() }
    defer {
        proxy.close()
        forwarding.cancel()
    }

    let pong = try await RakNetConnection.ping(proxy.localAddress)
    #expect(pong.advertisement == [42])
    let client = try await RakNetConnection.dial(proxy.localAddress)
    let incoming = try #require(try await withProxyDeadline("accept upstream") { try await backend.accept() })
    let request = Array(repeating: UInt8(0xfe), count: 20_100)
    try await client.send(request)
    let received = try await withProxyDeadline("receive upstream payload") { try await incoming.receive() }
    #expect(received == request)

    let reply: [UInt8] = [0xfe, 42]
    try await incoming.send(reply)
    let echoed = try await withProxyDeadline("receive downstream payload") { try await client.receive() }
    #expect(echoed == reply)
    try await client.close()
    proxy.close()
    try await forwarding.value
}

@Test(.timeLimit(.minutes(1))) func proxyClosesClientWhenUpstreamDoesNotAnswer() async throws {
    let loopback = RakNetEndpoint.ipv4(IPv4Endpoint(address: 0x7f000001, port: 0))
    let backend = try RakNetListener.listen(on: loopback)
    defer { backend.close() }
    backend.block(loopback)

    let proxy = try RakNetProxy(on: loopback, upstream: backend.localAddress, upstreamTimeout: .milliseconds(250))
    let forwarding = Task { try await proxy.run() }
    defer {
        proxy.close()
        forwarding.cancel()
    }

    let client = try await RakNetConnection.dial(proxy.localAddress)
    #expect(try await withProxyDeadline("receive downstream close") { try await client.receive() } == nil)
    proxy.close()
    try await forwarding.value
}

private struct ProxyTestTimeout: Error {
    let stage: String
}

private func withProxyDeadline<Value: Sendable>(
    _ stage: String, operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask(operation: operation)
        group.addTask {
            try await Task.sleep(for: .seconds(5))
            throw ProxyTestTimeout(stage: stage)
        }
        defer { group.cancelAll() }
        return try #require(try await group.next())
    }
}

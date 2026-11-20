import RakNet

public struct RakNetProxy: Sendable {
    private let listener: RakNetListener
    private let upstream: RakNetEndpoint

    public var localAddress: RakNetEndpoint { listener.localAddress }

    public init(on address: RakNetEndpoint, upstream: RakNetEndpoint, advertisement: [UInt8] = []) throws {
        listener = try RakNetListener.listen(on: address, advertisement: advertisement)
        self.upstream = upstream
    }

    public func run() async throws {
        defer { listener.close() }
        try await listener.handleConnections { await bridge($0) }
    }

    public func close() { listener.close() }

    private func bridge(_ client: RakNetConnection) async {
        do {
            let backend = try await RakNetConnection.dial(upstream)
            do {
                try await withThrowingTaskGroup(of: Void.self) { directions in
                    defer { directions.cancelAll() }
                    directions.addTask { try await Self.relay(from: client, to: backend) }
                    directions.addTask { try await Self.relay(from: backend, to: client) }
                    _ = try await directions.next()
                }
            } catch {}
            try? await backend.close()
        } catch {}
        try? await client.close()
    }

    private static func relay(from source: RakNetConnection, to destination: RakNetConnection) async throws {
        while let payload = try await source.receive() {
            try await destination.send(payload)
        }
    }
}

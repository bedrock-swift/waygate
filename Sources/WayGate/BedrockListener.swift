import RakNet

public final class BedrockListener: Sendable {
    public let localAddress: RakNetEndpoint
    public let connections: AsyncThrowingStream<BedrockSession, any Error>

    private let listener: RakNetListener
    private let worker: Task<Void, Never>

    public init(
        on address: RakNetEndpoint, login: BedrockLoginServer,
        guid: UInt64 = .random(in: 1...UInt64(Int64.max)), advertisement: [UInt8] = [],
        maximumConnections: Int = 128, loginTimeout: Duration = .seconds(10)
    ) throws {
        let listener = try RakNetListener.listen(
            on: address, guid: guid, advertisement: advertisement, maximumConnections: maximumConnections
        )
        let stream = AsyncThrowingStream<BedrockSession, any Error>.makeStream(bufferingPolicy: .bufferingOldest(maximumConnections))
        self.listener = listener
        localAddress = listener.localAddress
        connections = stream.stream
        worker = Task {
            do {
                try await listener.handleConnections { peer in
                    guard let session = try? await login.accept(on: peer, timeout: loginTimeout) else { return }
                    if case .enqueued = stream.continuation.yield(session) { return }
                    await session.close()
                }
                stream.continuation.finish()
            } catch is CancellationError {
                stream.continuation.finish()
            } catch {
                stream.continuation.finish(throwing: error)
            }
            listener.close()
        }
    }

    deinit { close() }

    public func close() {
        listener.close()
        worker.cancel()
    }
}

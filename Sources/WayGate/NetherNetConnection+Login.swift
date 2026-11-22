import NetherNet

extension BedrockLoginServer {
    public func handleConnections(
        on connections: AsyncStream<NetherNetConnection>, loginTimeout: Duration = .seconds(10),
        onError: (@Sendable (any Error) -> Void)? = nil,
        handle: @escaping @Sendable (BedrockSession) async throws -> Void
    ) async {
        await withDiscardingTaskGroup { workers in
            for await connection in connections {
                if Task.isCancelled {
                    await connection.close()
                    break
                }
                workers.addTask {
                    do {
                        try Task.checkCancellation()
                        let session = try await accept(on: connection, timeout: loginTimeout)
                        try await handle(session)
                    } catch {
                        if !Task.isCancelled { onError?(error) }
                    }
                    await connection.close()
                }
            }
            workers.cancelAll()
        }
    }

    public func accept(on connection: NetherNetConnection, timeout: Duration = .seconds(10)) async throws -> BedrockSession {
        guard let key = connection.authenticatedRemoteKey else {
            await connection.close()
            throw BedrockError.untrustedIdentity
        }
        return try await acceptNetherNet(on: NetherNetTransport(connection), authenticatedKey: key, timeout: timeout)
    }
}

private actor NetherNetTransport: BedrockTransport {
    private let connection: NetherNetConnection
    private var iterator: AsyncThrowingStream<[UInt8], any Error>.Iterator

    init(_ connection: NetherNetConnection) {
        self.connection = connection
        iterator = connection.messages.makeAsyncIterator()
    }

    func receive() async throws -> [UInt8]? {
        var current = iterator
        let message = try await current.next(isolation: self)
        iterator = current
        return message
    }

    func send(_ payload: [UInt8]) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while true {
            try Task.checkCancellation()
            do {
                try await connection.send(payload)
                return
            } catch ConnectionError.sendQueueFull {
                guard .now < deadline else { throw ConnectionError.sendQueueFull }
                try await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    func close() async {
        await connection.close()
    }
}

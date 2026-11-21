import NetherNet

extension BedrockLoginServer {
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

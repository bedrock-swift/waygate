import RakNet

private enum ListenerEvent: Sendable {
    case accepted(RakNetConnection?)
    case handled
}

extension RakNetListener {
    func handleConnections(_ handle: @escaping @Sendable (RakNetConnection) async -> Void) async throws {
        try await withThrowingTaskGroup(of: ListenerEvent.self) { sessions in
            sessions.addTask { .accepted(try await self.accept()) }
            while let event = try await sessions.next() {
                switch event {
                case let .accepted(peer?):
                    sessions.addTask { .accepted(try await self.accept()) }
                    sessions.addTask {
                        await handle(peer)
                        return .handled
                    }
                case .accepted(nil):
                    sessions.cancelAll()
                    return
                case .handled:
                    break
                }
            }
        }
    }
}

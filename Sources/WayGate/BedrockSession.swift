import Foundation
import RakNet

public protocol BedrockTransport: Sendable {
    func receive() async throws -> [UInt8]?
    func send(_ payload: [UInt8]) async throws
    func close() async throws
}

extension RakNetConnection: BedrockTransport {}

public actor BedrockSession {
    private let transport: any BedrockTransport
    private var incoming: BedrockCipher
    private var outgoing: BedrockCipher
    private var receiving = false
    private var sending = false
    private var negotiatingPacks = false
    private var packsNegotiated = false
    private var closed = false

    public nonisolated let login: LoginRequest
    public nonisolated let identity: BedrockIdentity?
    public nonisolated let clientData: Data

    init(
        transport: any BedrockTransport, login: LoginRequest, identity: BedrockIdentity?, clientData: Data, key: [UInt8]
    ) throws {
        self.transport = transport
        self.login = login
        self.identity = identity
        self.clientData = clientData
        incoming = try BedrockCipher(key: key)
        outgoing = try BedrockCipher(key: key)
    }

    public func receive() async throws -> [BedrockPacket]? {
        guard !negotiatingPacks else { throw BedrockError.concurrentOperation }
        return try await receiveBatch()
    }

    private func receiveBatch() async throws -> [BedrockPacket]? {
        guard !closed else { return nil }
        guard !receiving else { throw BedrockError.concurrentOperation }
        receiving = true
        defer { receiving = false }
        do {
            guard let bytes = try await transport.receive(), !closed else {
                await close()
                return nil
            }
            return try BedrockBatch.decode(incoming.open(bytes), framing: .negotiated)
        } catch {
            await close()
            throw error
        }
    }

    public func send(_ packets: [BedrockPacket]) async throws {
        guard !negotiatingPacks else { throw BedrockError.concurrentOperation }
        try await sendBatch(packets)
    }

    private func sendBatch(_ packets: [BedrockPacket]) async throws {
        guard !closed else { throw BedrockError.closed }
        guard !sending else { throw BedrockError.concurrentOperation }
        let bytes = try BedrockBatch.encode(packets, framing: .negotiated)
        sending = true
        defer { sending = false }
        do {
            try await transport.send(outgoing.seal(bytes))
        } catch {
            await close()
            throw error
        }
    }

    public func negotiateResourcePacks(
        _ negotiation: ResourcePackNegotiation, timeout: Duration = .seconds(120)
    ) async throws -> [BedrockPacket] {
        guard !closed else { throw BedrockError.closed }
        guard !receiving, !sending, !negotiatingPacks else { throw BedrockError.concurrentOperation }
        guard !packsNegotiated else { throw ResourcePackNegotiationError.unexpectedResponse }
        guard timeout > .zero else { throw BedrockError.timedOut }
        try Task.checkCancellation()

        negotiatingPacks = true
        defer { negotiatingPacks = false }
        let trailing = try await withThrowingTaskGroup(of: [BedrockPacket].self) { group in
            group.addTask { try await self.exchangeResourcePacks(negotiation) }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw BedrockError.timedOut
            }
            defer { group.cancelAll() }
            do {
                guard let packets = try await group.next() else { throw BedrockError.closed }
                return packets
            } catch {
                group.cancelAll()
                await close()
                throw error
            }
        }
        packsNegotiated = true
        return trailing
    }

    private func exchangeResourcePacks(_ negotiation: ResourcePackNegotiation) async throws -> [BedrockPacket] {
        var exchange = negotiation
        try await sendBatch([exchange.begin()])
        while let incoming = try await receiveBatch() {
            for (index, packet) in incoming.enumerated() {
                for response in try exchange.receive(packet) { try await sendBatch([response]) }
                if exchange.isComplete { return Array(incoming.dropFirst(index + 1)) }
            }
        }
        throw BedrockError.closed
    }

    public func close() async {
        guard !closed else { return }
        closed = true
        try? await transport.close()
    }
}

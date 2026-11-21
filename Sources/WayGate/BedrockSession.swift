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
    private let batchTransport: BedrockBatch.Transport
    private var incoming: BedrockCipher?
    private var outgoing: BedrockCipher?
    private var receiving = false
    private var sending = false
    private var exchanging = false
    private var packsNegotiated = false
    private var worldStarted = false
    private var chunkRadiusNegotiated = false
    private var closed = false

    public nonisolated let login: LoginRequest
    public nonisolated let identity: BedrockIdentity?
    public nonisolated let clientData: Data
    public private(set) var clientCacheEnabled: Bool?

    init(
        transport: any BedrockTransport, login: LoginRequest, identity: BedrockIdentity?, clientData: Data,
        batchTransport: BedrockBatch.Transport, key: [UInt8]?
    ) throws {
        self.transport = transport
        self.login = login
        self.identity = identity
        self.clientData = clientData
        self.batchTransport = batchTransport
        if let key {
            incoming = try BedrockCipher(key: key)
            outgoing = try BedrockCipher(key: key)
        }
    }

    public func receive() async throws -> [BedrockPacket]? {
        guard !exchanging else { throw BedrockError.concurrentOperation }
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
            return try BedrockBatch.decode(incoming?.open(bytes) ?? bytes, framing: .negotiated, transport: batchTransport)
        } catch {
            await close()
            throw error
        }
    }

    public func send(_ packets: [BedrockPacket]) async throws {
        guard !exchanging else { throw BedrockError.concurrentOperation }
        try await sendBatch(packets)
    }

    private func sendBatch(_ packets: [BedrockPacket]) async throws {
        guard !closed else { throw BedrockError.closed }
        guard !sending else { throw BedrockError.concurrentOperation }
        let bytes = try BedrockBatch.encode(packets, framing: .negotiated, transport: batchTransport)
        sending = true
        defer { sending = false }
        do {
            try await transport.send(outgoing?.seal(bytes) ?? bytes)
        } catch {
            await close()
            throw error
        }
    }

    public func negotiateResourcePacks(
        _ negotiation: ResourcePackNegotiation, timeout: Duration = .seconds(120)
    ) async throws -> [BedrockPacket] {
        guard !closed else { throw BedrockError.closed }
        guard !receiving, !sending, !exchanging else { throw BedrockError.concurrentOperation }
        guard !packsNegotiated else { throw ResourcePackNegotiationError.unexpectedResponse }
        let trailing = try await runExchange(timeout: timeout) { try await self.exchangeResourcePacks(negotiation) }
        packsNegotiated = true
        return trailing
    }

    public func negotiateChunkRadius(
        maximum: Int32, pendingPackets: [BedrockPacket] = [], timeout: Duration = .seconds(15)
    ) async throws -> (radius: Int32, pendingPackets: [BedrockPacket]) {
        guard !closed else { throw BedrockError.closed }
        guard !receiving, !sending, !exchanging else { throw BedrockError.concurrentOperation }
        guard worldStarted, !chunkRadiusNegotiated else { throw BedrockError.invalidSessionState }
        guard maximum > 0 else { throw BedrockError.malformed }
        let result = try await runExchange(timeout: timeout) {
            try await self.exchangeChunkRadius(maximum: maximum, pendingPackets: pendingPackets)
        }
        chunkRadiusNegotiated = true
        return result
    }

    private func runExchange<Result: Sendable>(
        timeout: Duration, operation: @escaping @Sendable () async throws -> Result
    ) async throws -> Result {
        guard timeout > .zero else { throw BedrockError.timedOut }
        try Task.checkCancellation()

        exchanging = true
        defer { exchanging = false }
        return try await withThrowingTaskGroup(of: Result.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                try await Task.sleep(for: timeout)
                throw BedrockError.timedOut
            }
            defer { group.cancelAll() }
            do {
                guard let result = try await group.next() else { throw BedrockError.closed }
                return result
            } catch {
                group.cancelAll()
                await close()
                throw error
            }
        }
    }

    private func exchangeChunkRadius(
        maximum: Int32, pendingPackets: [BedrockPacket]
    ) async throws -> (radius: Int32, pendingPackets: [BedrockPacket]) {
        var batch = pendingPackets
        var deferred: [BedrockPacket] = []
        var remainingBytes = BedrockBatch.maximumBytes
        while true {
            var radius: Int32?
            for packet in batch {
                if radius == nil, packet.id == RequestChunkRadius.packetID, packet.sender == 0, packet.target == 0 {
                    let request = try RequestChunkRadius(decoding: packet)
                    guard request.radius > 0 else { throw BedrockError.malformed }
                    radius = min(request.radius, maximum)
                    continue
                }
                guard deferred.count < BedrockBatch.maximumPackets, packet.payload.count <= remainingBytes else {
                    throw BedrockError.limitExceeded
                }
                remainingBytes -= packet.payload.count
                deferred.append(packet)
            }
            if let radius {
                try await sendBatch([ChunkRadiusUpdated(radius: radius).packet()])
                return (radius, deferred)
            }
            guard let next = try await receiveBatch() else { throw BedrockError.closed }
            batch = next
        }
    }

    private func exchangeResourcePacks(_ negotiation: ResourcePackNegotiation) async throws -> [BedrockPacket] {
        var exchange = negotiation
        try await sendBatch([exchange.begin()])
        while let incoming = try await receiveBatch() {
            for (index, packet) in incoming.enumerated() {
                for response in try exchange.receive(packet) { try await sendBatch([response]) }
                if exchange.isComplete {
                    clientCacheEnabled = exchange.clientCacheEnabled
                    return Array(incoming.dropFirst(index + 1))
                }
            }
        }
        throw BedrockError.closed
    }

    public func startGame(_ game: StartGame, items: ItemRegistry) async throws {
        guard !closed else { throw BedrockError.closed }
        guard !receiving, !sending, !exchanging else { throw BedrockError.concurrentOperation }
        guard packsNegotiated, !worldStarted else { throw BedrockError.invalidSessionState }
        try await sendBatch([game.packet(), items.packet()])
        worldStarted = true
    }

    public func close() async {
        guard !closed else { return }
        closed = true
        try? await transport.close()
    }
}

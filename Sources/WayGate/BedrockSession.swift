import Foundation
import RakNet

public protocol BedrockTransport: Sendable {
    func receive() async throws -> [UInt8]?
    func send(_ payload: [UInt8]) async throws
    func close() async throws
}

extension RakNetConnection: BedrockTransport {}

public actor BedrockSession {
    private struct WorldIdentity {
        let dimension: Int32
        let runtimeID: UInt64
    }

    private enum WorldState {
        case idle
        case started(WorldIdentity)
        case readyToSpawn(WorldIdentity, radius: Int32)
        case awaitingInitialization(UInt64)
        case spawned(UInt64)
    }

    private let transport: any BedrockTransport
    private let batchTransport: BedrockBatch.Transport
    private var incoming: BedrockCipher?
    private var outgoing: BedrockCipher?
    private var receiving = false
    private var sending = false
    private var exchanging = false
    private var packsNegotiated = false
    private var worldState = WorldState.idle
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
        guard case .started(let world) = worldState else { throw BedrockError.invalidSessionState }
        guard maximum > 0 else { throw BedrockError.malformed }
        let result = try await runExchange(timeout: timeout) {
            try await self.exchangeChunkRadius(maximum: maximum, pendingPackets: pendingPackets)
        }
        worldState = .readyToSpawn(world, radius: result.radius)
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
        let (radius, deferred) = try await receiveMatching(RequestChunkRadius.packetID, pendingPackets: pendingPackets) {
            let request = try RequestChunkRadius(decoding: $0)
            guard request.radius > 0 else { throw BedrockError.malformed }
            return min(request.radius, maximum)
        }
        try await sendBatch([ChunkRadiusUpdated(radius: radius).packet()])
        return (radius, deferred)
    }

    private func receiveMatching<Value>(
        _ id: UInt16, pendingPackets: [BedrockPacket], decode: (BedrockPacket) throws -> Value?
    ) async throws -> (Value, [BedrockPacket]) {
        var batch = pendingPackets
        var deferred: [BedrockPacket] = []
        var remainingBytes = BedrockBatch.maximumBytes
        while true {
            var match: Value?
            for packet in batch {
                if packet.id == NetworkStackLatency.packetID,
                   let response = try NetworkStackLatency.response(to: packet) {
                    try await sendBatch([response])
                    continue
                }
                if match == nil, packet.id == id, packet.sender == 0, packet.target == 0,
                   let value = try decode(packet) {
                    match = value
                    continue
                }
                guard deferred.count < BedrockBatch.maximumPackets, packet.payload.count <= remainingBytes else {
                    throw BedrockError.limitExceeded
                }
                remainingBytes -= packet.payload.count
                deferred.append(packet)
            }
            if let match { return (match, deferred) }
            guard let next = try await receiveBatch() else { throw BedrockError.closed }
            batch = next
        }
    }

    private func exchangeResourcePacks(_ negotiation: ResourcePackNegotiation) async throws -> [BedrockPacket] {
        var exchange = negotiation
        try await sendBatch([exchange.begin()])
        while let incoming = try await receiveBatch() {
            for (index, packet) in incoming.enumerated() {
                if packet.id == NetworkStackLatency.packetID {
                    if let response = try NetworkStackLatency.response(to: packet) { try await sendBatch([response]) }
                    continue
                }
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
        guard packsNegotiated, case .idle = worldState else { throw BedrockError.invalidSessionState }
        try await sendBatch([game.packet(), items.packet()])
        worldState = .started(WorldIdentity(dimension: game.world.dimension, runtimeID: game.player.runtimeID))
    }

    public func spawn(at position: SIMD3<Int32>, with chunks: [LevelChunk]) async throws {
        guard !closed else { throw BedrockError.closed }
        guard !receiving, !sending, !exchanging else { throw BedrockError.concurrentOperation }
        guard case let .readyToSpawn(world, radius) = worldState else { throw BedrockError.invalidSessionState }
        guard chunks.allSatisfy({ $0.dimension == world.dimension }) else { throw BedrockError.malformed }
        guard let blockRadius = UInt32(exactly: Int64(radius) * 16) else { throw BedrockError.limitExceeded }
        try Task.checkCancellation()

        exchanging = true
        defer { exchanging = false }
        do {
            let publisher = NetworkChunkPublisherUpdate(position: position, radiusInBlocks: blockRadius)
            try await sendBatch([publisher.packet()])
            for chunk in chunks {
                try Task.checkCancellation()
                try await sendBatch([chunk.packet()])
            }
            try Task.checkCancellation()
            try await sendBatch([PlayStatus.playerSpawn.packet()])
            worldState = .awaitingInitialization(world.runtimeID)
        } catch {
            await close()
            throw error
        }
    }

    public func waitForSpawn(
        pendingPackets: [BedrockPacket] = [], timeout: Duration = .seconds(15)
    ) async throws -> [BedrockPacket] {
        guard !closed else { throw BedrockError.closed }
        guard !receiving, !sending, !exchanging else { throw BedrockError.concurrentOperation }
        guard case .awaitingInitialization(let runtimeID) = worldState else { throw BedrockError.invalidSessionState }
        let (_, deferred) = try await runExchange(timeout: timeout) {
            try await self.receiveMatching(SetLocalPlayerAsInitialized.packetID, pendingPackets: pendingPackets) { packet -> Void? in
                let acknowledgement = try SetLocalPlayerAsInitialized(decoding: packet)
                guard acknowledgement.entityRuntimeID == runtimeID else { throw BedrockError.malformed }
                return ()
            }
        }
        worldState = .spawned(runtimeID)
        return deferred
    }

    public func waitForDimensionChange(
        pendingPackets: [BedrockPacket] = [], timeout: Duration = .seconds(15)
    ) async throws -> [BedrockPacket] {
        guard !closed else { throw BedrockError.closed }
        guard !receiving, !sending, !exchanging else { throw BedrockError.concurrentOperation }
        guard case .spawned(let runtimeID) = worldState else { throw BedrockError.invalidSessionState }
        let (_, deferred) = try await runExchange(timeout: timeout) {
            try await self.receiveMatching(PlayerAction.packetID, pendingPackets: pendingPackets) { packet -> Void? in
                let action = try PlayerAction(decoding: packet)
                guard action.action == PlayerAction.dimensionChangeDone else { return nil }
                guard action.runtimeID == runtimeID else { throw BedrockError.malformed }
                return ()
            }
        }
        return deferred
    }

    public func waitForRespawnRequest(
        pendingPackets: [BedrockPacket] = [], timeout: Duration = .seconds(15)
    ) async throws -> [BedrockPacket] {
        guard !closed else { throw BedrockError.closed }
        guard !receiving, !sending, !exchanging else { throw BedrockError.concurrentOperation }
        guard case .spawned(let runtimeID) = worldState else { throw BedrockError.invalidSessionState }
        let (_, deferred) = try await runExchange(timeout: timeout) {
            try await self.receiveMatching(Respawn.packetID, pendingPackets: pendingPackets) { packet -> Void? in
                let request = try Respawn(decoding: packet)
                guard request.state == .clientReadyToSpawn, request.runtimeID == runtimeID else {
                    throw BedrockError.malformed
                }
                return ()
            }
        }
        return deferred
    }

    public func close() async {
        guard !closed else { return }
        closed = true
        try? await transport.close()
    }
}

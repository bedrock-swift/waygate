public struct NetworkChunkPublisherUpdate: Equatable, Sendable {
    public static let packetID: UInt16 = 121
    private static let maximumSavedChunks: UInt32 = 9216

    public let position: SIMD3<Int32>
    public let radiusInBlocks: UInt32
    public let savedChunks: [SIMD2<Int32>]

    public init(position: SIMD3<Int32>, radiusInBlocks: UInt32, savedChunks: [SIMD2<Int32>] = []) {
        self.position = position
        self.radiusInBlocks = radiusInBlocks
        self.savedChunks = savedChunks
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        position = try reader.blockPosition()
        radiusInBlocks = try reader.varUInt()
        let count = try reader.littleEndian(UInt32.self)
        guard count <= Self.maximumSavedChunks else { throw BedrockError.limitExceeded }
        savedChunks = try reader.list(count: count, minimumElementSize: 2) {
            try SIMD2($0.varInt(), $0.varInt())
        }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard savedChunks.count <= Self.maximumSavedChunks else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendBlockPosition(position)
        payload.appendVarUInt(radiusInBlocks)
        payload.appendLittleEndian(UInt32(savedChunks.count))
        for chunk in savedChunks {
            payload.appendVarInt(chunk.x)
            payload.appendVarInt(chunk.y)
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

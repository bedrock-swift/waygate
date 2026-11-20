public struct SetSpawnPosition: Equatable, Sendable {
    public enum Kind: Int32, Sendable {
        case player = 0
        case world = 1
    }

    public static let packetID: UInt16 = 43
    public let kind: Kind
    public let position: SIMD3<Int32>
    public let dimension: Int32
    public let spawnPosition: SIMD3<Int32>

    public init(kind: Kind, position: SIMD3<Int32>, dimension: Int32, spawnPosition: SIMD3<Int32>) {
        self.kind = kind
        self.position = position
        self.dimension = dimension
        self.spawnPosition = spawnPosition
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        guard let kind = Kind(rawValue: try reader.varInt()) else { throw BedrockError.malformed }
        self.kind = kind
        position = try reader.blockPosition()
        dimension = try reader.varInt()
        spawnPosition = try reader.blockPosition()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarInt(kind.rawValue)
        payload.appendBlockPosition(position)
        payload.appendVarInt(dimension)
        payload.appendBlockPosition(spawnPosition)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

private extension BedrockReader {
    mutating func blockPosition() throws -> SIMD3<Int32> {
        try SIMD3(varInt(), varInt(), varInt())
    }
}

private extension [UInt8] {
    mutating func appendBlockPosition(_ position: SIMD3<Int32>) {
        appendVarInt(position.x)
        appendVarInt(position.y)
        appendVarInt(position.z)
    }
}

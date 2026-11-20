public struct RequestChunkRadius: Equatable, Sendable {
    public static let packetID: UInt16 = 69
    public let radius: Int32
    public let maximumRadius: UInt8

    public init(radius: Int32, maximumRadius: UInt8) {
        self.radius = radius
        self.maximumRadius = maximumRadius
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        radius = try reader.varInt()
        maximumRadius = try reader.byte()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarInt(radius)
        payload.append(maximumRadius)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

public struct ChunkRadiusUpdated: Equatable, Sendable {
    public static let packetID: UInt16 = 70
    public let radius: Int32

    public init(radius: Int32) {
        self.radius = radius
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        radius = try reader.varInt()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarInt(radius)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

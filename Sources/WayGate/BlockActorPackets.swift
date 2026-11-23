public struct BlockActorData: Equatable, Sendable {
    public static let packetID: UInt16 = 56
    public let position: SIMD3<Int32>
    public let data: NetworkNBT

    public init(position: SIMD3<Int32>, data: NetworkNBT) {
        self.position = position
        self.data = data
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        position = try reader.blockPosition()
        data = try NetworkNBT(reading: &reader)
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendBlockPosition(position)
        try payload.appendCompound(data)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

public struct BlockEvent: Equatable, Sendable {
    public static let packetID: UInt16 = 26
    public static let chestState: Int32 = 1
    public let position: SIMD3<Int32>
    public let eventType: Int32
    public let eventData: Int32

    public init(position: SIMD3<Int32>, eventType: Int32, eventData: Int32) {
        self.position = position
        self.eventType = eventType
        self.eventData = eventData
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        position = try reader.blockPosition()
        eventType = try reader.varInt()
        eventData = try reader.varInt()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendBlockPosition(position)
        payload.appendVarInt(eventType)
        payload.appendVarInt(eventData)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

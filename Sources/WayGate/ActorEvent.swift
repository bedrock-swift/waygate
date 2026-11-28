public struct ActorEvent: Equatable, Sendable {
    public static let packetID: UInt16 = 27
    public let runtimeID: UInt64
    public let eventType: UInt8
    public let eventData: Int32
    public let position: SIMD3<Float>?

    public init(runtimeID: UInt64, eventType: UInt8, eventData: Int32 = 0, position: SIMD3<Float>? = nil) {
        self.runtimeID = runtimeID
        self.eventType = eventType
        self.eventData = eventData
        self.position = position
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        runtimeID = try reader.varULong()
        eventType = try reader.byte()
        eventData = try reader.varInt()
        position = try reader.optional { try SIMD3($0.float32(), $0.float32(), $0.float32()) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarULong(runtimeID)
        payload.append(eventType)
        payload.appendVarInt(eventData)
        payload.appendOptional(position) { payload, position in
            payload.appendLittleEndian(position.x.bitPattern)
            payload.appendLittleEndian(position.y.bitPattern)
            payload.appendLittleEndian(position.z.bitPattern)
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

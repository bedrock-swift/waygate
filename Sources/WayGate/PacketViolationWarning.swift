public struct PacketViolationWarning: Equatable, Sendable {
    public static let packetID: UInt16 = 156
    public let type: Int32
    public let severity: Int32
    public let invalidPacketID: Int32
    public let context: String

    public init(type: Int32, severity: Int32, invalidPacketID: Int32, context: String) {
        self.type = type
        self.severity = severity
        self.invalidPacketID = invalidPacketID
        self.context = context
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        type = try reader.varInt()
        severity = try reader.varInt()
        invalidPacketID = try reader.varInt()
        context = try reader.string()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarInt(type)
        payload.appendVarInt(severity)
        payload.appendVarInt(invalidPacketID)
        try payload.appendString(context)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

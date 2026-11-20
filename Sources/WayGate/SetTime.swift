public struct SetTime: Equatable, Sendable {
    public static let packetID: UInt16 = 10
    public let time: Int32

    public init(time: Int32) {
        self.time = time
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        time = try reader.varInt()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarInt(time)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

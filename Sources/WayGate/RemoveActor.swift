public struct RemoveActor: Equatable, Sendable {
    public static let packetID: UInt16 = 14
    public let uniqueID: Int64

    public init(uniqueID: Int64) {
        self.uniqueID = uniqueID
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        let encoded = try reader.varULong()
        uniqueID = Int64(bitPattern: (encoded >> 1) ^ (0 &- (encoded & 1)))
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarULong((UInt64(bitPattern: uniqueID) << 1) ^ UInt64(bitPattern: uniqueID >> 63))
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

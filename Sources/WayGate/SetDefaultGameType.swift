public struct SetDefaultGameType: Equatable, Sendable {
    public static let packetID: UInt16 = 105
    public let gameType: Int32

    public init(gameType: Int32) {
        self.gameType = gameType
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        gameType = try reader.varInt()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarInt(gameType)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

public struct ClientCacheStatus: Equatable, Sendable {
    public static let packetID: UInt16 = 129
    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        enabled = try reader.bool()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: [enabled ? 1 : 0])
    }
}

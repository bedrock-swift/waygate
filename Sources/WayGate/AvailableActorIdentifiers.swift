public struct AvailableActorIdentifiers: Equatable, Sendable {
    public static let packetID: UInt16 = 119
    public let identifiers: NetworkNBT

    public init(identifiers: NetworkNBT) {
        self.identifiers = identifiers
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        identifiers = try NetworkNBT(bytes: packet.payload)
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: identifiers.bytes)
    }
}

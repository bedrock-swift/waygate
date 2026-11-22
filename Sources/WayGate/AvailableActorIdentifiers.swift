public struct AvailableActorIdentifiers: Equatable, Sendable {
    public static let packetID: UInt16 = 119
    public let identifiers: NetworkNBT

    public init(identifiers: NetworkNBT) {
        self.identifiers = identifiers
    }

    public init(names: [String]) throws {
        guard names.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var bytes: [UInt8] = [10, 0, 9]
        try bytes.appendString("idlist")
        bytes.append(10)
        bytes.appendVarInt(Int32(names.count))
        for name in names {
            bytes.append(8)
            try bytes.appendString("id")
            try bytes.appendString(name)
            bytes.append(0)
        }
        bytes.append(0)
        identifiers = try NetworkNBT(bytes: bytes)
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        identifiers = try NetworkNBT(bytes: packet.payload)
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: identifiers.bytes)
    }
}

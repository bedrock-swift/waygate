public struct Transfer: Equatable, Sendable {
    public static let packetID: UInt16 = 85

    public let address: String
    public let port: UInt16
    public let reloadWorld: Bool
    public let gathering: ServerJoinInformation.Gathering?

    public init(
        address: String, port: UInt16, reloadWorld: Bool = false,
        gathering: ServerJoinInformation.Gathering? = nil
    ) {
        self.address = address
        self.port = port
        self.reloadWorld = reloadWorld
        self.gathering = gathering
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        address = try reader.string()
        port = try reader.littleEndian(UInt16.self)
        reloadWorld = try reader.bool()
        gathering = try reader.optional { try ServerJoinInformation.Gathering(reading: &$0) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        try payload.appendString(address)
        payload.appendLittleEndian(port)
        payload.append(reloadWorld ? 1 : 0)
        try payload.appendOptional(gathering) { try $1.append(to: &$0) }
        guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

public enum PlayStatus: Int32, Equatable, Sendable {
    public static let packetID: UInt16 = 2

    case loginSuccess = 0
    case failedClient = 1
    case failedServer = 2
    case playerSpawn = 3
    case failedInvalidTenant = 4
    case failedVanillaEdition = 5
    case failedEduEdition = 6
    case failedServerFull = 7
    case failedEditorVanillaMismatch = 8
    case failedVanillaEditorMismatch = 9

    public init(decoding payload: [UInt8]) throws {
        var reader = BedrockReader(payload[...])
        let value = try reader.protocolVersion()
        guard reader.isEmpty, let status = PlayStatus(rawValue: value) else {
            throw BedrockError.malformed
        }
        self = status
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else {
            throw BedrockError.unexpectedPacket(packet.id)
        }
        try self.init(decoding: packet.payload)
    }

    public func encode() -> [UInt8] {
        var payload: [UInt8] = []
        payload.appendBigEndian(rawValue)
        return payload
    }

    public func packet() throws -> BedrockPacket {
        try BedrockPacket(id: Self.packetID, payload: encode())
    }
}

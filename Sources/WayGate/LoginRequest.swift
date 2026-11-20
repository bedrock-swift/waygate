public struct LoginRequest: Equatable, Sendable {
    public let protocolVersion: Int32
    public let identity: [UInt8]
    public let clientToken: String

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == 1 else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        protocolVersion = try reader.protocolVersion()
        guard let length = Int(exactly: try reader.varUInt()) else { throw BedrockError.malformed }
        var login = BedrockReader(try reader.read(length))
        identity = Array(try login.loginField())
        guard let token = String(validating: try login.loginField(), as: UTF8.self),
              !token.utf8.contains(0), login.isEmpty, reader.isEmpty else { throw BedrockError.malformed }
        clientToken = token
    }
}

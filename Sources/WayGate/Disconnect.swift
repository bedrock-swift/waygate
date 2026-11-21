public struct Disconnect: Equatable, Sendable {
    public struct Screen: Equatable, Sendable {
        public let message: String
        public let filteredMessage: String

        public init(message: String, filteredMessage: String = "") {
            self.message = message
            self.filteredMessage = filteredMessage
        }
    }

    public static let packetID: UInt16 = 5
    public let reason: Int32
    public let screen: Screen?

    public init(reason: Int32, screen: Screen? = nil) {
        self.reason = reason
        self.screen = screen
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        reason = try reader.varInt()
        switch try reader.varUInt() {
        case 0:
            screen = try Screen(message: reader.string(), filteredMessage: reader.string())
        case 1:
            screen = nil
        default:
            throw BedrockError.malformed
        }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarInt(reason)
        payload.appendVarUInt(screen == nil ? 1 : 0)
        if let screen {
            try payload.appendString(screen.message)
            try payload.appendString(screen.filteredMessage)
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

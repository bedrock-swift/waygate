public struct SetTitle: Equatable, Sendable {
    public enum Action: Int32, Sendable {
        case clear, reset, title, subtitle, actionBar, durations
        case titleTextObject, subtitleTextObject, actionBarTextObject
    }

    public static let packetID: UInt16 = 88
    public let action: Action
    public let text: String
    public let fadeIn: Int32
    public let stay: Int32
    public let fadeOut: Int32
    public let xuid: String
    public let platformOnlineID: String
    public let filteredMessage: String

    public init(
        action: Action, text: String = "", fadeIn: Int32 = 0, stay: Int32 = 0, fadeOut: Int32 = 0,
        xuid: String = "", platformOnlineID: String = "", filteredMessage: String = ""
    ) {
        self.action = action
        self.text = text
        self.fadeIn = fadeIn
        self.stay = stay
        self.fadeOut = fadeOut
        self.xuid = xuid
        self.platformOnlineID = platformOnlineID
        self.filteredMessage = filteredMessage
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        guard let action = Action(rawValue: try reader.varInt()) else { throw BedrockError.malformed }
        try self.init(
            action: action, text: reader.string(), fadeIn: reader.varInt(), stay: reader.varInt(),
            fadeOut: reader.varInt(), xuid: reader.string(), platformOnlineID: reader.string(),
            filteredMessage: reader.string()
        )
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarInt(action.rawValue)
        try payload.appendString(text)
        payload.appendVarInt(fadeIn)
        payload.appendVarInt(stay)
        payload.appendVarInt(fadeOut)
        try payload.appendString(xuid)
        try payload.appendString(platformOnlineID)
        try payload.appendString(filteredMessage)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

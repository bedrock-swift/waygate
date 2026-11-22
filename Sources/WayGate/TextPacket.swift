public struct TextPacket: Equatable, Sendable {
    public enum Kind: UInt8, Sendable {
        case raw, chat, translation, popup, jukeboxPopup, tip, system, whisper, announcement
        case objectWhisper, object, objectAnnouncement

        fileprivate var category: UInt8 {
            switch self {
            case .raw, .tip, .system, .objectWhisper, .object, .objectAnnouncement: 0
            case .chat, .whisper, .announcement: 1
            case .translation, .popup, .jukeboxPopup: 2
            }
        }
    }

    public static let packetID: UInt16 = 9
    public let kind: Kind
    public let message: String
    public let needsTranslation: Bool
    public let sourceName: String
    public let parameters: [String]
    public let xuid: String
    public let platformChatID: String
    public let filteredMessage: String?

    public init(
        kind: Kind, message: String, needsTranslation: Bool = false, sourceName: String = "",
        parameters: [String] = [], xuid: String = "", platformChatID: String = "", filteredMessage: String? = nil
    ) {
        self.kind = kind
        self.message = message
        self.needsTranslation = needsTranslation
        self.sourceName = sourceName
        self.parameters = parameters
        self.xuid = xuid
        self.platformChatID = platformChatID
        self.filteredMessage = filteredMessage
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        needsTranslation = try reader.bool()
        let category = try reader.byte()
        guard let kind = Kind(rawValue: try reader.byte()), kind.category == category else {
            throw BedrockError.malformed
        }
        self.kind = kind
        sourceName = category == 1 ? try reader.string() : ""
        message = try reader.string()
        if category == 2 {
            let count = try reader.varUInt()
            guard count <= 4 else { throw BedrockError.limitExceeded }
            parameters = try reader.list(count: count, minimumElementSize: 1) { try $0.string() }
        } else {
            parameters = []
        }
        xuid = try reader.string()
        platformChatID = try reader.string()
        filteredMessage = try reader.bool() ? try reader.string() : nil
        guard reader.isEmpty else { throw BedrockError.malformed }
        try validate()
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        try validate()
        let category = kind.category
        var payload: [UInt8] = [needsTranslation ? 1 : 0, category, kind.rawValue]
        if category == 1 { try payload.appendString(sourceName) }
        try payload.appendString(message)
        if category == 2 {
            payload.appendVarUInt(UInt32(parameters.count))
            for parameter in parameters { try payload.appendString(parameter) }
        }
        try payload.appendString(xuid)
        try payload.appendString(platformChatID)
        payload.append(filteredMessage == nil ? 0 : 1)
        if let filteredMessage { try payload.appendString(filteredMessage) }
        guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }

    private func validate() throws {
        guard !message.isEmpty, kind.category == 1 || sourceName.isEmpty, kind.category == 2 || parameters.isEmpty else {
            throw BedrockError.malformed
        }
        guard message.utf8.count <= 65_536, sourceName.utf8.count <= 256, parameters.count <= 4,
              xuid.utf8.count <= 64, platformChatID.utf8.count <= 256, (filteredMessage?.utf8.count ?? 0) <= 65_536 else {
            throw BedrockError.limitExceeded
        }
    }
}

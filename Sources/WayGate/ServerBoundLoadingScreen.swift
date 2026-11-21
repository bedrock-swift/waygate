public struct ServerBoundLoadingScreen: Equatable, Sendable {
    public enum Event: Int32, Sendable {
        case start = 1
        case end = 2
    }

    public static let packetID: UInt16 = 312
    public let event: Event
    public let screenID: UInt32?

    public init(event: Event, screenID: UInt32? = nil) {
        self.event = event
        self.screenID = screenID
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        guard let event = Event(rawValue: try reader.varInt()) else { throw BedrockError.malformed }
        self.event = event
        screenID = try reader.bool() ? reader.littleEndian(UInt32.self) : nil // absent on initial join
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarInt(event.rawValue)
        payload.append(screenID == nil ? 0 : 1)
        if let screenID { payload.appendLittleEndian(screenID) }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

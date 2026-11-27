public struct PlayerHotBar: Equatable, Sendable {
    public static let packetID: UInt16 = 48
    public let selectedSlot: UInt32
    public let windowID: UInt8
    public let selectSlot: Bool

    public init(selectedSlot: UInt32, windowID: UInt8, selectSlot: Bool) {
        self.selectedSlot = selectedSlot
        self.windowID = windowID
        self.selectSlot = selectSlot
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        selectedSlot = try reader.varUInt()
        windowID = try reader.byte()
        selectSlot = try reader.bool()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarUInt(selectedSlot)
        payload.append(windowID)
        payload.append(selectSlot ? 1 : 0)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

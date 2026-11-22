public struct InventorySlot: Equatable, Sendable {
    public static let packetID: UInt16 = 50
    public let windowID: UInt32
    public let slot: UInt32
    public let item: ItemInstance
    public let container: FullContainerName?
    public let storageItem: ItemInstance?

    public init(
        windowID: UInt32, slot: UInt32, item: ItemInstance, container: FullContainerName? = nil,
        storageItem: ItemInstance? = nil
    ) {
        self.windowID = windowID
        self.slot = slot
        self.item = item
        self.container = container
        self.storageItem = storageItem
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        windowID = try reader.varUInt()
        slot = try reader.varUInt()
        container = try reader.optional { try FullContainerName(reading: &$0) }
        storageItem = try reader.optional { try ItemInstance(reading: &$0) }
        item = try ItemInstance(reading: &reader)
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarUInt(windowID)
        payload.appendVarUInt(slot)
        payload.appendOptional(container) { $1.append(to: &$0) }
        try payload.appendOptional(storageItem) { try $1.append(to: &$0) }
        try item.append(to: &payload)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

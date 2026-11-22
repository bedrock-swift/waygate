public struct FullContainerName: Equatable, Sendable {
    public let id: UInt8
    public let dynamicID: UInt32?

    public init(id: UInt8, dynamicID: UInt32? = nil) {
        self.id = id
        self.dynamicID = dynamicID
    }

    init(reading reader: inout BedrockReader) throws {
        id = try reader.byte()
        dynamicID = try reader.optional { try $0.littleEndian(UInt32.self) }
    }

    func append(to payload: inout [UInt8]) {
        payload.append(id)
        payload.appendOptional(dynamicID) { $0.appendLittleEndian($1) }
    }
}

public struct InventoryContent: Equatable, Sendable {
    public static let packetID: UInt16 = 49
    public let windowID: UInt32
    public let slots: [ItemInstance]
    public let container: FullContainerName
    public let storageItem: ItemInstance

    public init(windowID: UInt32, slots: [ItemInstance], container: FullContainerName, storageItem: ItemInstance = .empty) {
        self.windowID = windowID
        self.slots = slots
        self.container = container
        self.storageItem = storageItem
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        windowID = try reader.varUInt()
        let count = try reader.varUInt()
        slots = try reader.list(count: count, minimumElementSize: 8) { try ItemInstance(reading: &$0) }
        container = try FullContainerName(reading: &reader)
        storageItem = try ItemInstance(reading: &reader)
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let count = UInt32(exactly: slots.count) else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendVarUInt(windowID)
        payload.appendVarUInt(count)
        for slot in slots { try slot.append(to: &payload) }
        container.append(to: &payload)
        try storageItem.append(to: &payload)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

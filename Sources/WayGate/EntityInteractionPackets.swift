public struct MobEquipment: Equatable, Sendable {
    public static let packetID: UInt16 = 31
    public let runtimeID: UInt64
    public let item: ItemInstance
    public let inventorySlot: UInt8
    public let hotbarSlot: UInt8
    public let windowID: UInt8

    public init(runtimeID: UInt64, item: ItemInstance, inventorySlot: UInt8, hotbarSlot: UInt8, windowID: UInt8) {
        self.runtimeID = runtimeID
        self.item = item
        self.inventorySlot = inventorySlot
        self.hotbarSlot = hotbarSlot
        self.windowID = windowID
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        runtimeID = try reader.varULong()
        item = try ItemInstance(reading: &reader)
        inventorySlot = try reader.byte()
        hotbarSlot = try reader.byte()
        windowID = try reader.byte()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarULong(runtimeID)
        try item.append(to: &payload)
        payload.append(contentsOf: [inventorySlot, hotbarSlot, windowID])
        guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

public struct Interact: Equatable, Sendable {
    public enum Action: UInt8, Sendable {
        case leaveVehicle = 3
        case mouseOverEntity, openNPC, openInventory
    }

    public static let packetID: UInt16 = 33
    public let action: Action
    public let targetRuntimeID: UInt64
    public let position: SIMD3<Float>?

    public init(action: Action, targetRuntimeID: UInt64, position: SIMD3<Float>? = nil) {
        self.action = action
        self.targetRuntimeID = targetRuntimeID
        self.position = position
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        guard let action = Action(rawValue: try reader.byte()) else { throw BedrockError.malformed }
        self.action = action
        targetRuntimeID = try reader.varULong()
        position = try reader.optional { try SIMD3($0.float32(), $0.float32(), $0.float32()) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload = [action.rawValue]
        payload.appendVarULong(targetRuntimeID)
        payload.appendOptional(position) { payload, position in
            payload.appendLittleEndian(position.x.bitPattern)
            payload.appendLittleEndian(position.y.bitPattern)
            payload.appendLittleEndian(position.z.bitPattern)
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

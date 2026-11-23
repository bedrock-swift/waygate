extension PlayerAuthInput {
    public struct ItemInteraction: Equatable, Sendable {
        public struct LegacySlot: Equatable, Sendable {
            public let containerID: UInt8
            public let slots: [UInt8]
        }

        public struct InventoryAction: Equatable, Sendable {
            public let sourceType: UInt32
            public let windowID: Int8?
            public let sourceFlags: UInt32?
            public let slot: UInt32
            public let oldItem: ItemInstance
            public let newItem: ItemInstance
        }

        public let legacyRequestID: Int32
        public let legacySlots: [LegacySlot]?
        public let inventoryActions: [InventoryAction]
        public let action: Int32
        public let trigger: UInt8
        public let blockPosition: SIMD3<Int32>
        public let face: UInt8
        public let hotbarSlot: Int32
        public let hand: UInt8
        public let heldItem: ItemInstance
        public let position: SIMD3<Float>
        public let clickedPosition: SIMD3<Float>
        public let blockRuntimeID: UInt32
        public let prediction: UInt8
        public let cooldownState: UInt8

        init(reading reader: inout BedrockReader) throws {
            legacyRequestID = try reader.varInt()
            legacySlots = try reader.optional { reader in
                let count = try reader.varUInt()
                return try reader.list(count: count, minimumElementSize: 2) {
                    try LegacySlot(containerID: $0.byte(), slots: Array($0.varBytes()))
                }
            }
            let count = try reader.varUInt()
            inventoryActions = try reader.list(count: count, minimumElementSize: 20) {
                try InventoryAction(
                    sourceType: $0.varUInt(), windowID: $0.optional { try Int8(bitPattern: $0.byte()) },
                    sourceFlags: $0.optional { try $0.varUInt() }, slot: $0.varUInt(),
                    oldItem: ItemInstance(reading: &$0), newItem: ItemInstance(reading: &$0)
                )
            }
            action = try reader.varInt()
            trigger = try reader.byte()
            blockPosition = try reader.blockPosition()
            face = try reader.byte()
            hotbarSlot = try reader.varInt()
            hand = try reader.byte()
            heldItem = try ItemInstance(reading: &reader)
            position = try SIMD3(reader.float32(), reader.float32(), reader.float32())
            clickedPosition = try SIMD3(reader.float32(), reader.float32(), reader.float32())
            blockRuntimeID = try reader.varUInt()
            prediction = try reader.byte()
            cooldownState = try reader.byte()
        }
    }

    public func itemInteraction() throws -> ItemInteraction? {
        var reader = BedrockReader(optionalData[...])
        return try reader.optional { try ItemInteraction(reading: &$0) }
    }
}

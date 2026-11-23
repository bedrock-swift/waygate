public struct ItemStackResponse: Equatable, Sendable {
    public struct Slot: Equatable, Sendable {
        public let slot: UInt8
        public let hotbarSlot: UInt8
        public let count: UInt8
        public let stackNetworkID: Int32?
        public let customName: String
        public let filteredCustomName: String?
        public let durabilityCorrection: Int16

        public init(
            slot: UInt8, hotbarSlot: UInt8, count: UInt8, stackNetworkID: Int32? = nil, customName: String = "",
            filteredCustomName: String? = nil, durabilityCorrection: Int16 = 0
        ) {
            self.slot = slot
            self.hotbarSlot = hotbarSlot
            self.count = count
            self.stackNetworkID = stackNetworkID
            self.customName = customName
            self.filteredCustomName = filteredCustomName
            self.durabilityCorrection = durabilityCorrection
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            slot = try reader.byte()
            hotbarSlot = try reader.byte()
            count = try reader.byte()
            stackNetworkID = try reader.optional { try $0.varInt() }
            customName = try reader.string()
            filteredCustomName = try reader.optional { try $0.string() }
            guard let durability = Int16(exactly: try reader.varInt()) else { throw BedrockError.malformed }
            durabilityCorrection = durability
        }

        fileprivate func append(to payload: inout [UInt8]) throws {
            payload.append(contentsOf: [slot, hotbarSlot, count])
            payload.appendOptional(stackNetworkID) { $0.appendVarInt($1) }
            try payload.appendString(customName)
            try payload.appendOptional(filteredCustomName) { try $0.appendString($1) }
            payload.appendVarInt(Int32(durabilityCorrection))
        }
    }

    public struct Container: Equatable, Sendable {
        public let name: FullContainerName
        public let slots: [Slot]

        public init(name: FullContainerName, slots: [Slot]) {
            self.name = name
            self.slots = slots
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            name = try FullContainerName(reading: &reader)
            let count = try reader.varUInt()
            slots = try reader.list(count: count, minimumElementSize: 7) { try Slot(reading: &$0) }
        }

        fileprivate func append(to payload: inout [UInt8]) throws {
            guard slots.count <= (BedrockBatch.maximumBytes - payload.count) / 7 else {
                throw BedrockError.limitExceeded
            }
            name.append(to: &payload)
            payload.appendVarUInt(UInt32(slots.count))
            for slot in slots { try slot.append(to: &payload) }
        }
    }

    public struct Entry: Equatable, Sendable {
        public let status: UInt8
        public let requestID: Int32
        public let containers: [Container]?

        public init(status: UInt8, requestID: Int32, containers: [Container]? = nil) {
            self.status = status
            self.requestID = requestID
            self.containers = containers
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            status = try reader.byte()
            requestID = try reader.varInt()
            containers = try reader.optional { reader in
                let count = try reader.varUInt()
                return try reader.list(count: count, minimumElementSize: 3) { try Container(reading: &$0) }
            }
        }

        fileprivate func append(to payload: inout [UInt8]) throws {
            payload.append(status)
            payload.appendVarInt(requestID)
            try payload.appendOptional(containers) { payload, containers in
                guard containers.count <= (BedrockBatch.maximumBytes - payload.count) / 3 else {
                    throw BedrockError.limitExceeded
                }
                payload.appendVarUInt(UInt32(containers.count))
                for container in containers { try container.append(to: &payload) }
            }
        }
    }

    public static let packetID: UInt16 = 148
    private static let maximumResponses: UInt32 = 4096
    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let count = try reader.varUInt()
        guard count <= Self.maximumResponses else { throw BedrockError.limitExceeded }
        entries = try reader.list(count: count, minimumElementSize: 3) { try Entry(reading: &$0) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard entries.count <= Self.maximumResponses else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendVarUInt(UInt32(entries.count))
        for entry in entries { try entry.append(to: &payload) }
        guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

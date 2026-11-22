public struct CreativeContent: Equatable, Sendable {
    public struct Group: Equatable, Sendable {
        public let category: UInt8
        public let name: String
        public let icon: ItemStack

        public init(category: UInt8, name: String = "", icon: ItemStack = .empty) {
            self.category = category
            self.name = name
            self.icon = icon
        }
    }

    public struct Entry: Equatable, Sendable {
        public let id: UInt32
        public let item: ItemStack
        public let groupIndex: UInt32

        public init(id: UInt32, item: ItemStack, groupIndex: UInt32) {
            self.id = id
            self.item = item
            self.groupIndex = groupIndex
        }
    }

    public static let packetID: UInt16 = 145
    public let groups: [Group]
    public let entries: [Entry]

    public init(groups: [Group] = [], entries: [Entry] = []) {
        self.groups = groups
        self.entries = entries
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let groupCount = try reader.varUInt()
        groups = try reader.list(count: groupCount, minimumElementSize: 8) {
            try Group(category: $0.byte(), name: $0.string(), icon: ItemStack(reading: &$0))
        }
        let entryCount = try reader.varUInt()
        entries = try reader.list(count: entryCount, minimumElementSize: 8) {
            try Entry(id: $0.varUInt(), item: ItemStack(reading: &$0), groupIndex: $0.varUInt())
        }
        guard reader.isEmpty else { throw BedrockError.malformed }
        try validateEntries()
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let groupCount = UInt32(exactly: groups.count), let entryCount = UInt32(exactly: entries.count) else {
            throw BedrockError.limitExceeded
        }
        try validateEntries()
        var payload: [UInt8] = []
        payload.appendVarUInt(groupCount)
        for group in groups {
            payload.append(group.category)
            try payload.appendString(group.name)
            try group.icon.append(to: &payload)
        }
        payload.appendVarUInt(entryCount)
        for entry in entries {
            payload.appendVarUInt(entry.id)
            try entry.item.append(to: &payload)
            payload.appendVarUInt(entry.groupIndex)
        }
        guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }

    private func validateEntries() throws {
        guard entries.allSatisfy({ UInt64($0.groupIndex) < UInt64(groups.count) }),
              Set(entries.map(\.id)).count == entries.count else { throw BedrockError.malformed }
    }
}

public struct ItemRegistry: Equatable, Sendable {
    public struct Item: Equatable, Sendable {
        public let name: String
        public let runtimeID: Int16
        public let componentBased: Bool
        public let version: Int32
        public let data: NetworkNBT

        public init(name: String, runtimeID: Int16, componentBased: Bool, version: Int32, data: NetworkNBT = .empty) {
            self.name = name
            self.runtimeID = runtimeID
            self.componentBased = componentBased
            self.version = version
            self.data = data
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            name = try reader.string()
            runtimeID = Int16(bitPattern: try reader.littleEndian(UInt16.self))
            componentBased = try reader.bool()
            version = try reader.varInt()
            data = try NetworkNBT(reading: &reader)
        }

        fileprivate func append(to payload: inout [UInt8]) throws {
            try payload.appendString(name)
            payload.appendLittleEndian(runtimeID)
            payload.append(componentBased ? 1 : 0)
            payload.appendVarInt(version)
            guard data.bytes.count <= BedrockBatch.maximumBytes - payload.count else { throw BedrockError.limitExceeded }
            payload.append(contentsOf: data.bytes)
        }
    }

    public static let packetID: UInt16 = 162
    public let items: [Item]

    public init(items: [Item]) {
        self.items = items
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let count = try reader.varUInt()
        items = try reader.list(count: count, minimumElementSize: 8) { try Item(reading: &$0) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let count = UInt32(exactly: items.count) else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendVarUInt(count)
        for item in items { try item.append(to: &payload) }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

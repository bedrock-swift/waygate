public struct UpdateAttributes: Equatable, Sendable {
    public struct Modifier: Equatable, Sendable {
        public let id: String
        public let name: String
        public let amount: Float
        public let operation: Int32
        public let operand: Int32
        public let serializable: Bool

        public init(id: String, name: String, amount: Float, operation: Int32, operand: Int32, serializable: Bool) {
            self.id = id
            self.name = name
            self.amount = amount
            self.operation = operation
            self.operand = operand
            self.serializable = serializable
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            try self.init(
                id: reader.string(), name: reader.string(), amount: reader.float32(),
                operation: Int32(bitPattern: reader.littleEndian(UInt32.self)),
                operand: Int32(bitPattern: reader.littleEndian(UInt32.self)), serializable: reader.bool()
            )
        }

        fileprivate func append(to payload: inout [UInt8]) throws {
            try payload.appendString(id)
            try payload.appendString(name)
            payload.appendLittleEndian(amount.bitPattern)
            payload.appendLittleEndian(operation)
            payload.appendLittleEndian(operand)
            payload.append(serializable ? 1 : 0)
        }
    }

    public struct Attribute: Equatable, Sendable {
        public let name: String
        public let minimum: Float
        public let maximum: Float
        public let value: Float
        public let defaultMinimum: Float
        public let defaultMaximum: Float
        public let defaultValue: Float
        public let modifiers: [Modifier]

        public init(
            name: String, minimum: Float, maximum: Float, value: Float, defaultMinimum: Float,
            defaultMaximum: Float, defaultValue: Float, modifiers: [Modifier] = []
        ) {
            self.name = name
            self.minimum = minimum
            self.maximum = maximum
            self.value = value
            self.defaultMinimum = defaultMinimum
            self.defaultMaximum = defaultMaximum
            self.defaultValue = defaultValue
            self.modifiers = modifiers
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            minimum = try reader.float32()
            maximum = try reader.float32()
            value = try reader.float32()
            defaultMinimum = try reader.float32()
            defaultMaximum = try reader.float32()
            defaultValue = try reader.float32()
            name = try reader.string()
            let count = try reader.varUInt()
            modifiers = try reader.list(count: count, minimumElementSize: 15) { try Modifier(reading: &$0) }
        }

        fileprivate func append(to payload: inout [UInt8]) throws {
            guard let count = UInt32(exactly: modifiers.count) else { throw BedrockError.limitExceeded }
            for number in [minimum, maximum, value, defaultMinimum, defaultMaximum, defaultValue] {
                payload.appendLittleEndian(number.bitPattern)
            }
            try payload.appendString(name)
            payload.appendVarUInt(count)
            for modifier in modifiers { try modifier.append(to: &payload) }
        }
    }

    public static let packetID: UInt16 = 29
    public let runtimeID: UInt64
    public let attributes: [Attribute]
    public let tick: UInt64

    public init(runtimeID: UInt64, attributes: [Attribute], tick: UInt64 = 0) {
        self.runtimeID = runtimeID
        self.attributes = attributes
        self.tick = tick
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        runtimeID = try reader.varULong()
        let count = try reader.varUInt()
        attributes = try reader.list(count: count, minimumElementSize: 26) { try Attribute(reading: &$0) }
        tick = try reader.varULong()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let count = UInt32(exactly: attributes.count) else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendVarULong(runtimeID)
        payload.appendVarUInt(count)
        for attribute in attributes { try attribute.append(to: &payload) }
        payload.appendVarULong(tick)
        guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

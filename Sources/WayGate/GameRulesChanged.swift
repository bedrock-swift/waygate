public struct GameRule: Equatable, Sendable {
    public enum Value: Equatable, Sendable {
        case unset
        case bool(Bool)
        case integer(UInt32)
        case float(Float)
    }

    public let name: String
    public let canBeModifiedByPlayer: Bool
    public let value: Value

    public init(name: String, canBeModifiedByPlayer: Bool = false, value: Value) {
        self.name = name
        self.canBeModifiedByPlayer = canBeModifiedByPlayer
        self.value = value
    }

    init(reading reader: inout BedrockReader) throws {
        name = try reader.string()
        canBeModifiedByPlayer = try reader.bool()
        switch try reader.varUInt() {
        case 0: value = .unset
        case 1: value = .bool(try reader.bool())
        case 2: value = .integer(try reader.littleEndian(UInt32.self))
        case 3: value = .float(Float(bitPattern: try reader.littleEndian(UInt32.self)))
        default: throw BedrockError.malformed
        }
    }

    func append(to payload: inout [UInt8]) throws {
        try payload.appendString(name)
        payload.append(canBeModifiedByPlayer ? 1 : 0)
        switch value {
        case .unset:
            payload.appendVarUInt(0)
        case let .bool(value):
            payload.appendVarUInt(1)
            payload.append(value ? 1 : 0)
        case let .integer(value):
            payload.appendVarUInt(2)
            payload.appendLittleEndian(value)
        case let .float(value):
            payload.appendVarUInt(3)
            payload.appendLittleEndian(value.bitPattern)
        }
        guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
    }
}

public struct GameRulesChanged: Equatable, Sendable {
    public static let packetID: UInt16 = 72
    public let rules: [GameRule]

    public init(rules: [GameRule]) {
        self.rules = rules
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let count = try reader.varUInt()
        rules = try reader.list(count: count, minimumElementSize: 3) { try GameRule(reading: &$0) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let count = UInt32(exactly: rules.count) else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendVarUInt(count)
        for rule in rules { try rule.append(to: &payload) }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

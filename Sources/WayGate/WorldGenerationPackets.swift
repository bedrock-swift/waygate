public struct FeatureRegistry: Equatable, Sendable {
    public struct Feature: Equatable, Sendable {
        public let name: String
        public let json: [UInt8]

        public init(name: String, json: [UInt8]) {
            self.name = name
            self.json = json
        }
    }

    public static let packetID: UInt16 = 191
    public let features: [Feature]

    public init(features: [Feature]) {
        self.features = features
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let count = try reader.varUInt()
        features = try reader.list(count: count, minimumElementSize: 2) {
            try Feature(name: $0.string(), json: Array($0.varBytes()))
        }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let count = UInt32(exactly: features.count) else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendVarUInt(count)
        for feature in features {
            try payload.appendString(feature.name)
            try payload.appendVarBytes(feature.json)
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

public struct JigsawStructureData: Equatable, Sendable {
    public static let packetID: UInt16 = 213
    public let structureData: NetworkNBT

    static func empty() throws -> Self {
        var bytes: [UInt8] = [10, 0]
        for name in ["processors", "template_pools", "jigsaws", "structure_sets"] {
            bytes.append(9)
            try bytes.appendString(name)
            bytes += [10, 0] // empty compound list
        }
        bytes.append(0)
        return try Self(structureData: NetworkNBT(bytes: bytes))
    }

    public init(structureData: NetworkNBT) {
        self.structureData = structureData
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        structureData = try NetworkNBT(bytes: packet.payload)
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: structureData.bytes)
    }
}

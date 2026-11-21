import Foundation

public struct DimensionData: Equatable, Sendable {
    public struct Definition: Equatable, Sendable {
        public let name: String
        public let minimumY: Int32
        public let heightRange: Int32
        public let generator: Int32
        public let dimensionType: Int32
        public let packID: UUID
        public let defaultBiome: String
        public let cloudHeight: Int32
        public let renderClouds: Bool

        public init(
            name: String, minimumY: Int32, heightRange: Int32, generator: Int32, dimensionType: Int32,
            packID: UUID, defaultBiome: String, cloudHeight: Int32, renderClouds: Bool
        ) {
            self.name = name
            self.minimumY = minimumY
            self.heightRange = heightRange
            self.generator = generator
            self.dimensionType = dimensionType
            self.packID = packID
            self.defaultBiome = defaultBiome
            self.cloudHeight = cloudHeight
            self.renderClouds = renderClouds
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            try self.init(
                name: reader.string(), minimumY: reader.varInt(), heightRange: reader.varInt(),
                generator: reader.varInt(), dimensionType: reader.varInt(), packID: reader.uuid(),
                defaultBiome: reader.string(), cloudHeight: reader.varInt(), renderClouds: reader.bool()
            )
        }

        fileprivate func append(to payload: inout [UInt8]) throws {
            try payload.appendString(name)
            payload.appendVarInt(minimumY)
            payload.appendVarInt(heightRange)
            payload.appendVarInt(generator)
            payload.appendVarInt(dimensionType)
            payload.appendUUID(packID)
            try payload.appendString(defaultBiome)
            payload.appendVarInt(cloudHeight)
            payload.append(renderClouds ? 1 : 0)
            guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        }
    }

    public static let packetID: UInt16 = 180
    public let definitions: [Definition]

    public init(definitions: [Definition]) {
        self.definitions = definitions
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let count = try reader.varUInt()
        definitions = try reader.list(count: count, minimumElementSize: 24) { try Definition(reading: &$0) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let count = UInt32(exactly: definitions.count) else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendVarUInt(count)
        for definition in definitions { try definition.append(to: &payload) }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

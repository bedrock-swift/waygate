public struct BiomeDefinitionList: Equatable, Sendable {
    public struct Definition: Equatable, Sendable {
        public let name: String
        public let id: Int16
        public let temperature: Float
        public let downfall: Float
        public let foliageSnow: Float
        public let depth: Float
        public let scale: Float
        public let mapWaterColor: UInt32
        public let rain: Bool
        public let tags: [String]?

        public init(
            name: String, id: Int16 = -1, temperature: Float, downfall: Float, foliageSnow: Float = 0,
            depth: Float, scale: Float, mapWaterColor: UInt32, rain: Bool, tags: [String]? = nil
        ) {
            self.name = name
            self.id = id
            self.temperature = temperature
            self.downfall = downfall
            self.foliageSnow = foliageSnow
            self.depth = depth
            self.scale = scale
            self.mapWaterColor = mapWaterColor
            self.rain = rain
            self.tags = tags
        }
    }

    public static let packetID: UInt16 = 122
    public let definitions: [Definition]

    public init(definitions: [Definition]) {
        self.definitions = definitions
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard definitions.count <= BedrockBatch.maximumBytes / 31 else { throw BedrockError.limitExceeded }
        var strings: [String] = []
        var indices: [String: UInt16] = [:]

        func index(of string: String) throws -> UInt16 {
            if let index = indices[string] { return index }
            guard let index = UInt16(exactly: strings.count) else { throw BedrockError.limitExceeded }
            strings.append(string)
            indices[string] = index
            return index
        }

        let names = try definitions.map { definition in
            guard let name = Int16(exactly: try index(of: definition.name)) else { throw BedrockError.limitExceeded }
            return name
        }

        var payload: [UInt8] = []
        payload.appendVarUInt(UInt32(definitions.count))
        for (definition, name) in zip(definitions, names) {
            payload.appendLittleEndian(name)
            payload.appendLittleEndian(definition.id)
            for value in [definition.temperature, definition.downfall, definition.foliageSnow, definition.depth, definition.scale] {
                payload.appendLittleEndian(value.bitPattern)
            }
            payload.appendLittleEndian(definition.mapWaterColor)
            payload.append(definition.rain ? 1 : 0)
            payload.append(definition.tags == nil ? 0 : 1)
            if let tags = definition.tags {
                guard tags.count <= (BedrockBatch.maximumBytes - payload.count) / 2 else {
                    throw BedrockError.limitExceeded
                }
                payload.appendVarUInt(UInt32(tags.count))
                for tag in tags { payload.appendLittleEndian(try index(of: tag)) }
            }
            payload.append(0) // client-side generation data absent
            guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        }
        payload.appendVarUInt(UInt32(strings.count))
        for string in strings { try payload.appendString(string) }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

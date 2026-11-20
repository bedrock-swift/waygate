public struct ResourcePackStack: Equatable, Sendable {
    public struct Pack: Equatable, Sendable {
        public let id: String
        public let version: String
        public let subPackName: String

        public init(id: String, version: String, subPackName: String = "") {
            self.id = id
            self.version = version
            self.subPackName = subPackName
        }
    }

    public struct Experiment: Equatable, Sendable {
        public let name: String
        public let enabled: Bool

        public init(name: String, enabled: Bool) {
            self.name = name
            self.enabled = enabled
        }
    }

    public static let packetID: UInt16 = 7
    public let required: Bool
    public let behaviorPacks: [Pack]
    public let texturePacks: [Pack]
    public let baseGameVersion: String
    public let experiments: [Experiment]
    public let experimentsPreviouslyToggled: Bool
    public let includeEditorPacks: Bool

    public init(
        required: Bool = false, behaviorPacks: [Pack] = [], texturePacks: [Pack] = [],
        baseGameVersion: String, experiments: [Experiment] = [], experimentsPreviouslyToggled: Bool = false,
        includeEditorPacks: Bool = false
    ) {
        self.required = required
        self.behaviorPacks = behaviorPacks
        self.texturePacks = texturePacks
        self.baseGameVersion = baseGameVersion
        self.experiments = experiments
        self.experimentsPreviouslyToggled = experimentsPreviouslyToggled
        self.includeEditorPacks = includeEditorPacks
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        required = try reader.bool()
        behaviorPacks = try Self.readPacks(&reader)
        texturePacks = try Self.readPacks(&reader)
        baseGameVersion = try reader.string()
        let count = try reader.littleEndian(UInt32.self)
        experiments = try reader.list(count: count, minimumElementSize: 2) {
            try Experiment(name: $0.string(), enabled: $0.bool())
        }
        experimentsPreviouslyToggled = try reader.bool()
        includeEditorPacks = try reader.bool()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let count = UInt32(exactly: experiments.count) else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = [required ? 1 : 0]
        try Self.writePacks(behaviorPacks, into: &payload)
        try Self.writePacks(texturePacks, into: &payload)
        try payload.appendString(baseGameVersion)
        payload.appendLittleEndian(count)
        for experiment in experiments {
            try payload.appendString(experiment.name)
            payload.append(experiment.enabled ? 1 : 0)
        }
        payload.append(experimentsPreviouslyToggled ? 1 : 0)
        payload.append(includeEditorPacks ? 1 : 0)
        guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }

    private static func readPacks(_ reader: inout BedrockReader) throws -> [Pack] {
        let count = try reader.varUInt()
        return try reader.list(count: count, minimumElementSize: 3) {
            try Pack(id: $0.string(), version: $0.string(), subPackName: $0.string())
        }
    }

    private static func writePacks(_ packs: [Pack], into payload: inout [UInt8]) throws {
        guard let count = UInt32(exactly: packs.count) else { throw BedrockError.limitExceeded }
        payload.appendVarUInt(count)
        for pack in packs {
            try payload.appendString(pack.id)
            try payload.appendString(pack.version)
            try payload.appendString(pack.subPackName)
        }
    }
}

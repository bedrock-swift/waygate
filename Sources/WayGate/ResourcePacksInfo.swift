import Foundation

public struct ResourcePacksInfo: Equatable, Sendable {
    public struct Pack: Equatable, Sendable {
        public let id: UUID
        public let version: String
        public let size: UInt64
        public let contentKey: String
        public let subPackName: String
        public let contentIdentity: String
        public let hasScripts: Bool
        public let isAddon: Bool
        public let rtxEnabled: Bool
        public let downloadURL: String

        public init(
            id: UUID, version: String, size: UInt64, contentKey: String = "", subPackName: String = "",
            contentIdentity: String = "", hasScripts: Bool = false, isAddon: Bool = false,
            rtxEnabled: Bool = false, downloadURL: String = ""
        ) {
            self.id = id
            self.version = version
            self.size = size
            self.contentKey = contentKey
            self.subPackName = subPackName
            self.contentIdentity = contentIdentity
            self.hasScripts = hasScripts
            self.isAddon = isAddon
            self.rtxEnabled = rtxEnabled
            self.downloadURL = downloadURL
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            try self.init(
                id: reader.uuid(), version: reader.string(), size: reader.littleEndian(UInt64.self),
                contentKey: reader.string(), subPackName: reader.string(), contentIdentity: reader.string(),
                hasScripts: reader.bool(), isAddon: reader.bool(), rtxEnabled: reader.bool(),
                downloadURL: reader.string()
            )
        }

        fileprivate func write(to payload: inout [UInt8]) throws {
            payload.appendUUID(id)
            try payload.appendString(version)
            payload.appendLittleEndian(size)
            try payload.appendString(contentKey)
            try payload.appendString(subPackName)
            try payload.appendString(contentIdentity)
            payload.append(contentsOf: [hasScripts ? 1 : 0, isAddon ? 1 : 0, rtxEnabled ? 1 : 0])
            try payload.appendString(downloadURL)
        }
    }

    public static let packetID: UInt16 = 6
    private static let zeroUUID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    public let required: Bool
    public let hasAddons: Bool
    public let hasScripts: Bool
    public let forceDisableVibrantVisuals: Bool
    public let worldTemplateID: UUID?
    public let worldTemplateVersion: String
    public let texturePacks: [Pack]

    public init(
        required: Bool = false, hasAddons: Bool = false, hasScripts: Bool = false,
        forceDisableVibrantVisuals: Bool = false, worldTemplateID: UUID? = nil, worldTemplateVersion: String = "",
        texturePacks: [Pack] = []
    ) {
        self.required = required
        self.hasAddons = hasAddons
        self.hasScripts = hasScripts
        self.forceDisableVibrantVisuals = forceDisableVibrantVisuals
        self.worldTemplateID = worldTemplateID == Self.zeroUUID ? nil : worldTemplateID
        self.worldTemplateVersion = worldTemplateVersion
        self.texturePacks = texturePacks
    }

    public init(decoding packet: BedrockPacket, format: ResourcePackFormat = .v26_60) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        required = try reader.bool()
        hasAddons = try reader.bool()
        hasScripts = try reader.bool()
        forceDisableVibrantVisuals = try reader.bool()
        let templateID = try reader.uuid()
        worldTemplateID = templateID == Self.zeroUUID ? nil : templateID
        worldTemplateVersion = try reader.string()
        let count = format == .legacy ? UInt32(try reader.littleEndian(UInt16.self)) : try reader.varUInt()
        texturePacks = try reader.list(count: count, minimumElementSize: 32) { try Pack(reading: &$0) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0, format: ResourcePackFormat = .v26_60) throws -> BedrockPacket {
        var payload: [UInt8] = [required ? 1 : 0, hasAddons ? 1 : 0, hasScripts ? 1 : 0, forceDisableVibrantVisuals ? 1 : 0]
        payload.appendUUID(worldTemplateID ?? Self.zeroUUID)
        try payload.appendString(worldTemplateVersion)
        if format == .legacy {
            guard let count = UInt16(exactly: texturePacks.count) else { throw BedrockError.limitExceeded }
            payload.appendLittleEndian(count)
        } else {
            guard let count = UInt32(exactly: texturePacks.count) else { throw BedrockError.limitExceeded }
            payload.appendVarUInt(count)
        }
        for pack in texturePacks { try pack.write(to: &payload) }
        guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

extension BedrockReader {
    mutating func uuid() throws -> UUID {
        let bytes = Array(try read(16))
        return UUID(uuid: (
            bytes[7], bytes[6], bytes[5], bytes[4], bytes[3], bytes[2], bytes[1], bytes[0],
            bytes[15], bytes[14], bytes[13], bytes[12], bytes[11], bytes[10], bytes[9], bytes[8]
        )) // little endian within each half
    }
}

extension [UInt8] {
    mutating func appendUUID(_ id: UUID) {
        Swift.withUnsafeBytes(of: id.uuid) { bytes in
            append(contentsOf: bytes.prefix(8).reversed())
            append(contentsOf: bytes.suffix(8).reversed())
        }
    }
}

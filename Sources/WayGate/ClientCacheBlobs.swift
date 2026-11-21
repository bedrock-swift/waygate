public struct ClientCacheBlobStatus: Equatable, Sendable {
    public static let packetID: UInt16 = 135
    private static let maximumHashes: UInt32 = 4095

    public let missing: [UInt64]
    public let found: [UInt64]

    public init(missing: [UInt64], found: [UInt64]) {
        self.missing = missing
        self.found = found
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        missing = try Self.readHashes(from: &reader)
        found = try Self.readHashes(from: &reader)
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard missing.count <= Self.maximumHashes, found.count <= Self.maximumHashes else {
            throw BedrockError.limitExceeded
        }
        var payload: [UInt8] = []
        for hashes in [missing, found] {
            payload.appendVarUInt(UInt32(hashes.count))
            for hash in hashes { payload.appendLittleEndian(hash) }
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }

    private static func readHashes(from reader: inout BedrockReader) throws -> [UInt64] {
        let count = try reader.varUInt()
        guard count <= maximumHashes else { throw BedrockError.limitExceeded }
        return try reader.list(count: count, minimumElementSize: 8) { try $0.littleEndian(UInt64.self) }
    }
}

public struct ClientCacheMissResponse: Equatable, Sendable {
    public struct Blob: Equatable, Sendable {
        public let hash: UInt64
        public let data: [UInt8]

        public init(hash: UInt64, data: [UInt8]) {
            self.hash = hash
            self.data = data
        }
    }

    public static let packetID: UInt16 = 136
    private static let maximumBlobs: UInt32 = 4095

    public let blobs: [Blob]

    public init(blobs: [Blob]) {
        self.blobs = blobs
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let count = try reader.varUInt()
        guard count <= Self.maximumBlobs else { throw BedrockError.limitExceeded }
        blobs = try reader.list(count: count, minimumElementSize: 9) { reader in
            try Blob(hash: reader.littleEndian(UInt64.self), data: Array(reader.varBytes()))
        }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard blobs.count <= Self.maximumBlobs else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendVarUInt(UInt32(blobs.count))
        for blob in blobs {
            guard blob.data.count <= BedrockBatch.maximumBytes - payload.count - 8 else {
                throw BedrockError.limitExceeded
            }
            payload.appendLittleEndian(blob.hash)
            try payload.appendVarBytes(blob.data)
            guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

public struct LevelChunk: Equatable, Sendable {
    public static let packetID: UInt16 = 58
    private static let maximumSubChunks: UInt32 = 64

    public let x: Int32
    public let z: Int32
    public let dimension: Int32
    public let subChunkCount: UInt32
    public let subChunkLimit: Int32?
    public let cacheEnabled: Bool
    public let blobHashes: [UInt64]
    public let payload: [UInt8]
    public let clientBiomeUpdate: Bool

    public init(
        x: Int32, z: Int32, dimension: Int32, subChunkCount: UInt32, subChunkLimit: Int32? = nil,
        cacheEnabled: Bool = false, blobHashes: [UInt64] = [], payload: [UInt8], clientBiomeUpdate: Bool = false
    ) {
        self.x = x
        self.z = z
        self.dimension = dimension
        self.subChunkCount = subChunkCount
        self.subChunkLimit = subChunkLimit
        self.cacheEnabled = cacheEnabled
        self.blobHashes = blobHashes
        self.payload = payload
        self.clientBiomeUpdate = clientBiomeUpdate
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        x = try reader.varInt()
        z = try reader.varInt()
        dimension = try reader.varInt()
        subChunkCount = try reader.varUInt()
        guard subChunkCount <= Self.maximumSubChunks else { throw BedrockError.limitExceeded }
        subChunkLimit = try reader.bool() ? try reader.varInt() : nil
        cacheEnabled = try reader.bool()
        let hashCount = try reader.varUInt()
        guard hashCount <= Self.maximumSubChunks + 1 else { throw BedrockError.limitExceeded }
        blobHashes = try reader.list(count: hashCount, minimumElementSize: 8) {
            try $0.littleEndian(UInt64.self)
        }
        payload = Array(try reader.varBytes())
        clientBiomeUpdate = try reader.bool()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard subChunkCount <= Self.maximumSubChunks, blobHashes.count <= Self.maximumSubChunks + 1 else {
            throw BedrockError.limitExceeded
        }
        var bytes: [UInt8] = []
        bytes.appendVarInt(x)
        bytes.appendVarInt(z)
        bytes.appendVarInt(dimension)
        bytes.appendVarUInt(subChunkCount)
        bytes.append(subChunkLimit == nil ? 0 : 1)
        if let subChunkLimit { bytes.appendVarInt(subChunkLimit) }
        bytes.append(cacheEnabled ? 1 : 0)
        bytes.appendVarUInt(UInt32(blobHashes.count))
        for hash in blobHashes { bytes.appendLittleEndian(hash) }
        try bytes.appendVarBytes(payload)
        guard bytes.count < BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        bytes.append(clientBiomeUpdate ? 1 : 0)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: bytes)
    }
}

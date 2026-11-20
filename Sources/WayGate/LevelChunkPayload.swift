public struct LevelChunkPayload: Equatable, Sendable {
    public let subChunks: [SubChunk]
    public let biomes: [PalettedStorage]
    public let blockEntities: [UInt8]

    public init(subChunks: [SubChunk], biomes: [PalettedStorage], blockEntities: [UInt8] = []) throws {
        guard (1...64).contains(biomes.count), (0...biomes.count).contains(subChunks.count),
              Set(subChunks.map(\.y)).count == subChunks.count else { throw BedrockError.malformed }
        guard blockEntities.count < BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        self.subChunks = subChunks
        self.biomes = biomes
        self.blockEntities = blockEntities
    }

    public init(decoding bytes: [UInt8], subChunkCount: UInt32, biomeCount: Int) throws {
        guard (1...64).contains(biomeCount), subChunkCount <= UInt32(biomeCount) else {
            throw BedrockError.malformed
        }
        guard bytes.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(bytes[...])
        let subChunks = try reader.list(count: subChunkCount, minimumElementSize: 3) {
            try SubChunk(reading: &$0)
        }
        var biomes: [PalettedStorage] = []
        biomes.reserveCapacity(biomeCount)
        for _ in 0..<biomeCount {
            let header = try reader.byte()
            if header == 0xff {
                guard let previous = biomes.last else { throw BedrockError.malformed }
                biomes.append(previous)
            } else {
                biomes.append(try PalettedStorage(reading: &reader, header: header))
            }
        }
        guard try reader.byte() == 0 else { throw BedrockError.malformed }
        let entities = Array(try reader.read(reader.remaining))
        try self.init(subChunks: subChunks, biomes: biomes, blockEntities: entities)
    }

    public func encode() throws -> [UInt8] {
        var bytes: [UInt8] = []
        for chunk in subChunks { try chunk.append(to: &bytes) }
        var previous: PalettedStorage?
        for biome in biomes {
            if biome == previous {
                bytes.append(0xff)
            } else {
                biome.append(to: &bytes)
                previous = biome
            }
            guard bytes.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        }
        guard blockEntities.count < BedrockBatch.maximumBytes - bytes.count else { throw BedrockError.limitExceeded }
        bytes.append(0) // border block count
        bytes.append(contentsOf: blockEntities)
        return bytes
    }
}

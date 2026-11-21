import Testing
import WayGate

@Test func assemblesSubChunksBiomesAndBlockEntities() throws {
    let lower = try SubChunk(y: -4, layers: [.init(uniform: 3)])
    let upper = try SubChunk(y: -3, layers: [])
    let named = try NetworkNBT(bytes: [10, 1, 116, 0])
    let chunk = try LevelChunkPayload(
        subChunks: [lower, upper], biomes: [.init(uniform: 7), .init(uniform: 7), .init(uniform: 8)],
        blockEntityCompounds: [.empty, named]
    )
    let wire: [UInt8] = [9, 1, 0xfc, 1, 6, 9, 0, 0xfd, 1, 14, 0xff, 1, 16, 0, 10, 0, 0, 10, 1, 116, 0]
    #expect(try chunk.encode() == wire)
    let packet = try LevelChunk(x: 0, z: 0, dimension: 0, subChunkCount: 2, payload: chunk.encode()).packet()
    let decoded = try LevelChunk(decoding: packet)
    let payload = try LevelChunkPayload(decoding: decoded.payload, subChunkCount: decoded.subChunkCount, biomeCount: 3)
    #expect(payload == chunk)
    #expect(try payload.decodeBlockEntities() == [.empty, named])
    let incomplete = try LevelChunkPayload(decoding: Array(wire.dropLast()), subChunkCount: 2, biomeCount: 3)
    #expect(throws: BedrockError.malformed) { try incomplete.decodeBlockEntities() }
    #expect(throws: BedrockError.malformed) {
        try LevelChunkPayload(decoding: [0xff, 0], subChunkCount: 0, biomeCount: 1)
    }
    #expect(throws: BedrockError.malformed) {
        try LevelChunkPayload(subChunks: [lower, lower], biomes: chunk.biomes)
    }
}

@Test func encodesChunkCoordinatesAndCacheFields() throws {
    let chunk = LevelChunk(
        x: -2, z: 3, dimension: 1, subChunkCount: 2, subChunkLimit: 8, cacheEnabled: true,
        blobHashes: [0x0102030405060708, 9, 10], payload: [0xaa, 0xbb], clientBiomeUpdate: true
    )
    let wire: [UInt8] = [
        3, 6, 2, 2, 1, 16, 1, 3, 8, 7, 6, 5, 4, 3, 2, 1, 9, 0, 0, 0, 0, 0, 0, 0,
        10, 0, 0, 0, 0, 0, 0, 0, 2, 0xaa, 0xbb, 1
    ]
    let packet = try BedrockPacket(id: 58, target: 1, payload: wire)
    #expect(try chunk.packet(target: 1) == packet)
    #expect(try LevelChunk(decoding: packet) == chunk)

    let direct = LevelChunk(x: 0, z: 0, dimension: 0, subChunkCount: 0, payload: [0xbe])
    #expect(try LevelChunk(decoding: direct.packet()) == direct)
}

@Test func rejectsTruncatedAndOversizedChunks() throws {
    let truncated = try BedrockPacket(id: 58, payload: [0, 0, 0, 0, 0, 0, 0, 2, 1])
    #expect(throws: BedrockError.malformed) { try LevelChunk(decoding: truncated) }
    let tooManySections = try BedrockPacket(id: 58, payload: [0, 0, 0, 65])
    #expect(throws: BedrockError.limitExceeded) { try LevelChunk(decoding: tooManySections) }
    let tooManyHashes = LevelChunk(
        x: 0, z: 0, dimension: 0, subChunkCount: 64, blobHashes: Array(repeating: 0, count: 66), payload: []
    )
    #expect(throws: BedrockError.limitExceeded) { try tooManyHashes.packet() }
}

@Test func validatesChunkRequestLimitsAndCacheMetadata() throws {
    for limit: Int32 in [-2, 65] {
        let chunk = LevelChunk(x: 0, z: 0, dimension: 0, subChunkCount: 0, subChunkLimit: limit, payload: [])
        #expect(throws: BedrockError.malformed) { try chunk.packet() }
    }
    let invalidLimit = try BedrockPacket(id: 58, payload: [0, 0, 0, 0, 1, 3, 0, 0, 0, 0])
    #expect(throws: BedrockError.malformed) { try LevelChunk(decoding: invalidLimit) }

    let disabledCache = LevelChunk(x: 0, z: 0, dimension: 0, subChunkCount: 0, blobHashes: [0], payload: [])
    #expect(throws: BedrockError.malformed) { try disabledCache.packet() }
    let invalidCache = try BedrockPacket(id: 58, payload: [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    #expect(throws: BedrockError.malformed) { try LevelChunk(decoding: invalidCache) }

    let unlimited = LevelChunk(x: 0, z: 0, dimension: 0, subChunkCount: 0, subChunkLimit: -1, payload: [])
    #expect(try LevelChunk(decoding: unlimited.packet()) == unlimited)
}

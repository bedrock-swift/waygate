import Testing
import WayGate

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

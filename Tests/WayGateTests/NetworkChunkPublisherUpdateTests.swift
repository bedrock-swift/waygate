import Testing
import WayGate

@Test func encodesChunkPublisherPositionRadiusAndSavedChunks() throws {
    let update = NetworkChunkPublisherUpdate(
        position: SIMD3(-2, 64, 3), radiusInBlocks: 128, savedChunks: [SIMD2(-4, 5), SIMD2(0, -1)]
    )
    let bytes: [UInt8] = [3, 0x80, 1, 6, 0x80, 1, 2, 0, 0, 0, 7, 10, 0, 1]
    let packet = try BedrockPacket(id: 121, target: 1, payload: bytes)
    #expect(try update.packet(target: 1) == packet)
    #expect(try NetworkChunkPublisherUpdate(decoding: packet) == update)
    let truncated = try BedrockPacket(id: 121, payload: Array(bytes.dropLast()))
    #expect(throws: BedrockError.malformed) { try NetworkChunkPublisherUpdate(decoding: truncated) }
    let tooManyChunks = try BedrockPacket(id: 121, payload: [0, 0, 0, 0, 1, 36, 0, 0])
    #expect(throws: BedrockError.limitExceeded) { try NetworkChunkPublisherUpdate(decoding: tooManyChunks) }
}

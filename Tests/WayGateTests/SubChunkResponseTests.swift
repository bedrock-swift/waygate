import Testing
import WayGate

@Test func encodesSubChunkResponseEntriesWithAndWithoutCacheData() throws {
    let response = SubChunkResponse(cacheEnabled: true, dimension: 1, center: SIMD3(0, -1, 0), entries: [
        .init(offset: SIMD3(-1, 2, 3), status: .allAir, heightMap: .tooLow, renderHeightMap: .copied),
        .init(offset: .zero, status: .success, data: [0xaa], blobHash: 0x0102)
    ])
    let wire: [UInt8] = [
        1, 2, 0, 0, 0, 0, 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 0, 2,
        0xff, 2, 3, 6, 0, 3, 4, 0,
        0, 0, 0, 1, 1, 1, 0xaa, 0, 0, 1, 2, 1, 0, 0, 0, 0, 0, 0
    ]
    let packet = try BedrockPacket(id: 174, target: 1, payload: wire)
    #expect(try response.packet(target: 1) == packet)
    #expect(try SubChunkResponse(decoding: packet) == response)
    let truncated = try BedrockPacket(id: 174, payload: Array(wire.dropLast()))
    #expect(throws: BedrockError.malformed) { try SubChunkResponse(decoding: truncated) }
}

@Test func encodesSixteenHeightMapRowsAndRejectsInvalidRowLength() throws {
    let heights = Array(repeating: Int8(-1), count: 256)
    let response = SubChunkResponse(dimension: 0, center: .zero, entries: [
        .init(offset: .zero, status: .success, heightMap: .heights(heights))
    ])
    let packet = try response.packet()
    var expected = Array(repeating: UInt8(0), count: 14)
    expected += [1, 0, 0, 0, 1, 0, 1]
    let row: [UInt8] = [16] + Array(repeating: 255, count: 16)
    for _ in 0..<16 { expected += row }
    expected += [0, 0]
    #expect(packet.payload == expected)
    #expect(try SubChunkResponse(decoding: packet) == response)
    expected[21] = 15
    let invalid = try BedrockPacket(id: 174, payload: expected)
    #expect(throws: BedrockError.malformed) { try SubChunkResponse(decoding: invalid) }
}

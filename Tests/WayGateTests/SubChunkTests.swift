import Testing
import WayGate

@Test func encodesUniformSubChunkLayers() throws {
    let chunk = try SubChunk(y: -4, layers: [.init(uniform: 3), .init(uniform: .max)])
    let bytes: [UInt8] = [9, 2, 0xfc, 1, 6, 1, 1]
    #expect(try chunk.encode() == bytes)
    #expect(try SubChunk(decoding: bytes) == chunk)
}

@Test func storesPaletteIndicesInLittleEndianWords() throws {
    var blocks = Array(repeating: UInt32(7), count: PalettedStorage.valueCount)
    blocks[1] = 99
    blocks[32] = 99
    let chunk = try SubChunk(y: 0, layers: [PalettedStorage(values: blocks)])
    var bytes: [UInt8] = [9, 1, 0, 3, 2, 0, 0, 0, 1, 0, 0, 0]
    bytes += Array(repeating: 0, count: 126 * 4)
    bytes += [4, 14, 0xc6, 1]
    #expect(try chunk.encode() == bytes)
    #expect(try SubChunk(decoding: bytes) == chunk)

    let truncated = Array(bytes.dropLast())
    #expect(throws: BedrockError.malformed) { try SubChunk(decoding: truncated) }
}

@Test func padsPaletteWordsWhenAnIndexCannotFit() throws {
    var blocks = Array(repeating: UInt32(0), count: PalettedStorage.valueCount)
    for index in 1...4 { blocks[index] = UInt32(index) }
    blocks[9] = 4
    blocks[10] = 4
    let chunk = try SubChunk(y: 0, layers: [PalettedStorage(values: blocks)])
    let bytes = try chunk.encode()
    #expect(bytes.count == 4 + 410 * 4 + 6)
    #expect(Array(bytes[8..<12]) == [4, 0, 0, 0])
    #expect(try SubChunk(decoding: bytes) == chunk)
}

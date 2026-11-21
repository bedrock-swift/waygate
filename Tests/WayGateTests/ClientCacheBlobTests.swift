import Testing
import WayGate

@Test func separatesMissingAndFoundChunkHashes() throws {
    let status = ClientCacheBlobStatus(missing: [0x0102030405060708], found: [0x12])
    let wire: [UInt8] = [1, 8, 7, 6, 5, 4, 3, 2, 1, 1, 0x12, 0, 0, 0, 0, 0, 0, 0]
    let packet = try BedrockPacket(id: 135, sender: 1, payload: wire)
    #expect(try status.packet(sender: 1) == packet)
    #expect(try ClientCacheBlobStatus(decoding: packet) == status)

    let oversized = try BedrockPacket(id: 135, payload: [0x80, 0x20])
    #expect(throws: BedrockError.limitExceeded) { try ClientCacheBlobStatus(decoding: oversized) }
}

@Test func encodesChunkCacheMissData() throws {
    let response = ClientCacheMissResponse(blobs: [.init(hash: 0x0102, data: [0xaa, 0xbb])])
    let wire: [UInt8] = [1, 2, 1, 0, 0, 0, 0, 0, 0, 2, 0xaa, 0xbb]
    let packet = try BedrockPacket(id: 136, payload: wire)
    #expect(try response.packet() == packet)
    #expect(try ClientCacheMissResponse(decoding: packet) == response)

    let truncated = try BedrockPacket(id: 136, payload: Array(wire.dropLast()))
    #expect(throws: BedrockError.malformed) { try ClientCacheMissResponse(decoding: truncated) }
}

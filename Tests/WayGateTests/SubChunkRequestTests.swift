import Testing
import WayGate

@Test func encodesSubChunkOffsetsAndCenter() throws {
    let request = SubChunkRequest(dimension: 2, center: SIMD3(-2, 15, 256), offsets: [SIMD3(-128, 0, 127)])
    let wire: [UInt8] = [4, 1, 0x80, 0, 0x7f, 0xfe, 0xff, 0xff, 0xff, 15, 0, 0, 0, 0, 1, 0, 0]
    let packet = try BedrockPacket(id: 175, sender: 1, payload: wire)
    #expect(try request.packet(sender: 1) == packet)
    #expect(try SubChunkRequest(decoding: packet) == request)

    let truncated = try BedrockPacket(id: 175, payload: Array(wire.dropLast()))
    #expect(throws: BedrockError.malformed) { try SubChunkRequest(decoding: truncated) }
    let oversized = try BedrockPacket(id: 175, payload: [0, 0x81, 0x40])
    #expect(throws: BedrockError.limitExceeded) { try SubChunkRequest(decoding: oversized) }
}

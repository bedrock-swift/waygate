import Testing
import WayGate

@Test func encodesDimensionChangeAndLoadingScreenID() throws {
    let change = ChangeDimension(dimension: 2, position: SIMD3(1, -2, 0.5), respawn: true, screenID: 0x01020304)
    let wire: [UInt8] = [4, 0, 0, 0x80, 0x3f, 0, 0, 0, 0xc0, 0, 0, 0, 0x3f, 1, 1, 4, 3, 2, 1]
    let packet = try BedrockPacket(id: 61, target: 1, payload: wire)
    #expect(try change.packet(target: 1) == packet)
    #expect(try ChangeDimension(decoding: packet) == change)

    let simple = ChangeDimension(dimension: 0, position: .zero)
    #expect(try ChangeDimension(decoding: simple.packet()) == simple)
    let truncated = try BedrockPacket(id: 61, payload: Array(wire.dropLast()))
    #expect(throws: BedrockError.malformed) { try ChangeDimension(decoding: truncated) }
}

import Testing
import WayGate

@Test func encodesBlockUpdateWithSignedCoordinatesAndLayer() throws {
    let flags = UpdateBlock.Flags(rawValue: 0x10a)
    let update = UpdateBlock(position: SIMD3(-17, -64, 128), runtimeID: 300, flags: flags, layer: 1)
    let payload: [UInt8] = [33, 127, 0x80, 2, 0xac, 2, 0x8a, 2, 1]
    let packet = try BedrockPacket(id: 21, payload: payload)
    #expect(try update.packet() == packet)
    #expect(try UpdateBlock(decoding: packet) == update)
    let malformed = try BedrockPacket(id: 21, payload: payload + [0])
    #expect(throws: BedrockError.malformed) { try UpdateBlock(decoding: malformed) }
}

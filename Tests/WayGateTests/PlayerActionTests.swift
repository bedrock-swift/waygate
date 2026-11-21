import Testing
import WayGate

@Test func encodesPlayerActionPositionsAndFace() throws {
    let action = PlayerAction(
        runtimeID: 128, action: 25, blockPosition: SIMD3(-1, 2, 3), resultPosition: SIMD3(4, -5, 6), blockFace: -1
    )
    let bytes: [UInt8] = [0x80, 1, 50, 1, 4, 6, 8, 9, 12, 1]
    let packet = try BedrockPacket(id: 36, sender: 1, payload: bytes)
    #expect(try action.packet(sender: 1) == packet)
    #expect(try PlayerAction(decoding: packet) == action)
    let truncated = try BedrockPacket(id: 36, payload: Array(bytes.dropLast()))
    #expect(throws: BedrockError.malformed) { try PlayerAction(decoding: truncated) }

    let done = PlayerAction(runtimeID: 1, action: PlayerAction.dimensionChangeDone)
    #expect(try done.packet().payload == [1, 28, 0, 0, 0, 0, 0, 0, 0])
}

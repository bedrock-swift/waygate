import Testing
import WayGate

@Test func encodesMoveActorAbsolute() throws {
    let value = MoveActorAbsolute(runtimeID: 300, flags: 2, position: SIMD3(1, -2, 0), rotationBytes: SIMD3(0, 64, 128))
    let packet = try BedrockPacket(id: 18, target: 1, payload: [172, 2, 2, 0, 0, 128, 63, 0, 0, 0, 192, 0, 0, 0, 0, 0, 64, 128])
    #expect(try value.packet(target: 1) == packet)
    #expect(try MoveActorAbsolute(decoding: packet) == value)
    #expect(value.rotationDegrees == SIMD3(0, 90, 180))

    let truncated = try BedrockPacket(id: 18, payload: Array(packet.payload.dropLast()))
    #expect(throws: BedrockError.malformed) { try MoveActorAbsolute(decoding: truncated) }
}

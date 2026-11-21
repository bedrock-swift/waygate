import Testing
import WayGate

@Test func encodesActorVelocityAndTick() throws {
    let motion = SetActorMotion(runtimeID: 128, velocity: SIMD3(1, -2, 0.5), tick: 300)
    let bytes: [UInt8] = [0x80, 1, 0, 0, 0x80, 0x3f, 0, 0, 0, 0xc0, 0, 0, 0, 0x3f, 0xac, 2]
    let packet = try BedrockPacket(id: 40, target: 1, payload: bytes)
    #expect(try motion.packet(target: 1) == packet)
    #expect(try SetActorMotion(decoding: packet) == motion)
    let truncated = try BedrockPacket(id: 40, payload: Array(bytes.dropLast()))
    #expect(throws: BedrockError.malformed) { try SetActorMotion(decoding: truncated) }
}

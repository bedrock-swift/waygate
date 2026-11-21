import Testing
import WayGate

@Test func encodesRespawnPositionStateAndRuntimeID() throws {
    let respawn = Respawn(position: SIMD3(1, -2, 0.5), state: .clientReadyToSpawn, runtimeID: 300)
    let payload: [UInt8] = [0, 0, 0x80, 0x3f, 0, 0, 0, 0xc0, 0, 0, 0, 0x3f, 2, 0xac, 2]
    let packet = try BedrockPacket(id: 45, sender: 1, target: 2, payload: payload)
    #expect(try respawn.packet(sender: 1, target: 2) == packet)
    #expect(try Respawn(decoding: packet) == respawn)
    let unknownState = Array(payload.prefix(12)) + [3] + Array(payload.suffix(2))
    for invalid in [unknownState, Array(payload.dropLast()), payload + [0]] {
        let packet = try BedrockPacket(id: 45, payload: invalid)
        #expect(throws: BedrockError.malformed) { try Respawn(decoding: packet) }
    }
}

import Testing
import WayGate

@Test func encodesSpawnPositionAndDimension() throws {
    let spawn = SetSpawnPosition(
        kind: .world, position: SIMD3(-4, 64, 3), dimension: 2, spawnPosition: SIMD3(7, -1, 0)
    )
    let wire: [UInt8] = [2, 7, 0x80, 1, 6, 4, 14, 1, 0]
    let packet = try BedrockPacket(id: 43, target: 1, payload: wire)
    #expect(try spawn.packet(target: 1) == packet)
    #expect(try SetSpawnPosition(decoding: packet) == spawn)

    let truncated = try BedrockPacket(id: 43, payload: Array(wire.dropLast()))
    #expect(throws: BedrockError.malformed) { try SetSpawnPosition(decoding: truncated) }
}

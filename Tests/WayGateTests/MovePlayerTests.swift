import Testing
import WayGate

@Test func encodesPlayerMovementAndTick() throws {
    let move = MovePlayer(
        runtimeID: 128, position: SIMD3(1, -2, 0.5), pitch: 0, yaw: 0, headYaw: 0,
        onGround: true, riddenRuntimeID: 7, tick: 300
    )
    let bytes: [UInt8] = [
        0x80, 1, 0, 0, 0x80, 0x3f, 0, 0, 0, 0xc0, 0, 0, 0, 0x3f,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 7, 0, 0xac, 2
    ]
    let packet = try BedrockPacket(id: 19, target: 1, payload: bytes)
    #expect(try move.packet(target: 1) == packet)
    #expect(try MovePlayer(decoding: packet) == move)
}

@Test func encodesTeleportDataAndRejectsTruncation() throws {
    let move = MovePlayer(runtimeID: 1, position: .zero, pitch: 0, yaw: 0, headYaw: 0,
                          mode: .teleport, teleport: .init(cause: 3, sourceActorType: -1), tick: 9)
    let bytes: [UInt8] = [1] + Array(repeating: 0, count: 24)
        + [2, 0, 0, 1, 3, 0, 0, 0, 0xff, 0xff, 0xff, 0xff, 9]
    let packet = try BedrockPacket(id: 19, payload: bytes)
    #expect(try move.packet() == packet)
    #expect(try MovePlayer(decoding: packet) == move)
    let truncated = try BedrockPacket(id: 19, payload: Array(bytes.dropLast()))
    #expect(throws: BedrockError.malformed) { try MovePlayer(decoding: truncated) }
    var invalid = bytes
    invalid[25] = 0
    let normal = try BedrockPacket(id: 19, payload: invalid)
    #expect(throws: BedrockError.malformed) { try MovePlayer(decoding: normal) }
}

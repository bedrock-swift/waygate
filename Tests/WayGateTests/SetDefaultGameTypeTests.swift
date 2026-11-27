import Testing
import WayGate

@Test func encodesSetDefaultGameType() throws {
    let value = SetDefaultGameType(gameType: -1)
    let packet = try BedrockPacket(id: 105, target: 1, payload: [1])
    #expect(try value.packet(target: 1) == packet)
    #expect(try SetDefaultGameType(decoding: packet) == value)

    let truncated = try BedrockPacket(id: 105, payload: Array(packet.payload.dropLast()))
    #expect(throws: BedrockError.malformed) { try SetDefaultGameType(decoding: truncated) }
}

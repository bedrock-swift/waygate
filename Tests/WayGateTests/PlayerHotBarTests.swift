import Testing
import WayGate

@Test func encodesPlayerHotBar() throws {
    let value = PlayerHotBar(selectedSlot: 8, windowID: 0, selectSlot: true)
    let packet = try BedrockPacket(id: 48, target: 1, payload: [8, 0, 1])
    #expect(try value.packet(target: 1) == packet)
    #expect(try PlayerHotBar(decoding: packet) == value)

    let truncated = try BedrockPacket(id: 48, payload: Array(packet.payload.dropLast()))
    #expect(throws: BedrockError.malformed) { try PlayerHotBar(decoding: truncated) }
}

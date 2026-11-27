import Testing
import WayGate

@Test func encodesRemoveActor() throws {
    let value = RemoveActor(uniqueID: -65)
    let packet = try BedrockPacket(id: 14, target: 1, payload: [129, 1])
    #expect(try value.packet(target: 1) == packet)
    #expect(try RemoveActor(decoding: packet) == value)

    let truncated = try BedrockPacket(id: 14, payload: Array(packet.payload.dropLast()))
    #expect(throws: BedrockError.malformed) { try RemoveActor(decoding: truncated) }
}

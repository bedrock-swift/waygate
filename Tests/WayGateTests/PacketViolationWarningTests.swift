import Testing
import WayGate

@Test func encodesPacketViolationWarnings() throws {
    let warning = PacketViolationWarning(type: 0, severity: 2, invalidPacketID: 174, context: "bad")
    let packet = try BedrockPacket(id: 156, sender: 1, payload: [0, 4, 220, 2, 3, 98, 97, 100])
    #expect(try warning.packet(sender: 1) == packet)
    #expect(try PacketViolationWarning(decoding: packet) == warning)
    let truncated = try BedrockPacket(id: 156, payload: Array(packet.payload.dropLast()))
    #expect(throws: BedrockError.malformed) { try PacketViolationWarning(decoding: truncated) }
}

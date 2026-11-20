@testable import WayGate
import Testing

@Test func encodesAndDecodesPlayStatusExactBytes() throws {
    #expect(PlayStatus.loginSuccess.encode() == [0x00, 0x00, 0x00, 0x00])
    #expect(PlayStatus.failedClient.encode() == [0x00, 0x00, 0x00, 0x01])
    #expect(PlayStatus.failedServer.encode() == [0x00, 0x00, 0x00, 0x02])
    #expect(PlayStatus.playerSpawn.encode() == [0x00, 0x00, 0x00, 0x03])
    #expect(PlayStatus.failedServerFull.encode() == [0x00, 0x00, 0x00, 0x07])

    #expect(try PlayStatus(decoding: [0x00, 0x00, 0x00, 0x00]) == .loginSuccess)
    #expect(try PlayStatus(decoding: [0x00, 0x00, 0x00, 0x01]) == .failedClient)
    #expect(try PlayStatus(decoding: [0x00, 0x00, 0x00, 0x02]) == .failedServer)

    let packet = try PlayStatus.failedClient.packet()
    #expect(packet.id == 2)
    #expect(packet.payload == [0x00, 0x00, 0x00, 0x01])
    #expect(try PlayStatus(decoding: packet) == .failedClient)
}

@Test func rejectsMalformedPlayStatusPackets() throws {
    #expect(throws: BedrockError.malformed) {
        try PlayStatus(decoding: [0x00, 0x00, 0x01])
    }
    #expect(throws: BedrockError.malformed) {
        try PlayStatus(decoding: [0x00, 0x00, 0x00, 0x01, 0x00])
    }
    #expect(throws: BedrockError.malformed) {
        try PlayStatus(decoding: [0x00, 0x00, 0x00, 0x63])
    }

    let wrongPacket = try BedrockPacket(id: 99, payload: [0x00, 0x00, 0x00, 0x00])
    #expect(throws: BedrockError.unexpectedPacket(99)) {
        try PlayStatus(decoding: wrongPacket)
    }
}

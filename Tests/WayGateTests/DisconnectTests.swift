import Testing
import WayGate

@Test func encodesDisconnectWithAndWithoutAScreen() throws {
    let verbose = Disconnect(reason: 64, screen: .init(message: "Bye", filteredMessage: "OK"))
    let wire: [UInt8] = [0x80, 1, 0, 3, 66, 121, 101, 2, 79, 75]
    let packet = try BedrockPacket(id: 5, payload: wire)
    #expect(try verbose.packet() == packet)
    #expect(try Disconnect(decoding: packet) == verbose)

    let silent = Disconnect(reason: -1)
    let hidden = try BedrockPacket(id: 5, payload: [1, 1])
    #expect(try silent.packet() == hidden)
    #expect(try Disconnect(decoding: hidden) == silent)
}

@Test func rejectsMalformedDisconnectPayloads() throws {
    for bytes: [UInt8] in [[0, 2], [0, 0, 3, 66], [0, 1, 0]] {
        let packet = try BedrockPacket(id: 5, payload: bytes)
        #expect(throws: BedrockError.malformed) { try Disconnect(decoding: packet) }
    }
}

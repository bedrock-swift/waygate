@testable import WayGate
import Testing

@Test func resourcePackResponseMatchesTheBedrockWireFormat() throws {
    let wire: [UInt8] = [2, 2, 0, 3, 97, 95, 49, 4, 98, 95, 50, 48]
    let packet = try BedrockPacket(id: 8, sender: 1, payload: wire)
    let response = try ResourcePackClientResponse(decoding: packet)
    #expect(response.status == .sendPacks)
    #expect(response.packIDs == ["a_1", "b_20"])
    #expect(try response.packet(sender: 1) == packet)
    #expect(try ResourcePackClientResponse(status: .completed).packet().payload == [4, 0, 0])

    for invalid: [UInt8] in [[0, 0, 0], [2, 0, 1], [2, 1, 0, 1, 255], [4, 0, 0, 1]] {
        let packet = try BedrockPacket(id: 8, payload: invalid)
        #expect(throws: BedrockError.malformed) { try ResourcePackClientResponse(decoding: packet) }
    }
}

@Test func parsesAnIndependentNetworkSettingsBatch() throws {
    let wire: [UInt8] = [0xfe, 6, 0xc1, 1, 0, 0, 3, 0x33]
    let packet = try #require(try BedrockBatch.decode(wire).first)
    #expect(packet.id == 193)
    #expect(packet.payload == [0, 0, 3, 0x33])
    #expect(try BedrockBatch.encode([packet]) == wire)
    #expect(throws: BedrockError.malformed) { try BedrockBatch.decode(Array(wire.dropLast())) }
}

@Test func decodesSnappyLiteralAndOverlappingCopy() throws {
    let data: [UInt8] = [10, 8, 0x61, 0x62, 0x63, 26, 3, 0]
    #expect(try Snappy.decode(data[...], limit: 10) == Array("abcabcabca".utf8))
    #expect(throws: BedrockError.limitExceeded) { try Snappy.decode(data[...], limit: 9) }
    let invalid: [UInt8] = [4, 1, 1]
    #expect(throws: BedrockError.malformed) { try Snappy.decode(invalid[...], limit: 4) }

    let packet = try BedrockPacket(id: 10, sender: 1, target: 3, payload: Array(repeating: 42, count: 20_100))
    let compressed = try BedrockBatch.encode([packet], framing: .negotiated)
    #expect(compressed[1] == 1)
    #expect(compressed.count < 1_100)
    #expect(try BedrockBatch.decode(compressed, framing: .negotiated) == [packet])
}

@Test func cipherMatchesTwoIndependentSequentialFrames() throws {
    let key = (0..<32).map(UInt8.init)
    var outgoing = try BedrockCipher(key: key)
    var incoming = try BedrockCipher(key: key)
    let first: [UInt8] = [0xfe, 0xff, 1, 4]
    let second: [UInt8] = [0xfe, 0xff, 5, 2, 0, 0, 0, 0]
    let firstExpected: [UInt8] = [0xfe, 0xb8, 0x03, 0xd2, 0x62, 0x25, 0x03, 0x4a, 0xbc, 0x3f, 0xb1, 0xcd]
    let secondExpected: [UInt8] = [0xfe, 0x74, 0xb4, 0xeb, 0x78, 0x6d, 0x83, 0xd6, 0xdf, 0x41, 0xf3, 0xa9, 0x0f, 0xa1, 0x4f, 0x11]
    let encodedFirst = try outgoing.seal(first)
    let encodedSecond = try outgoing.seal(second)
    #expect(encodedFirst == firstExpected)
    #expect(encodedSecond == secondExpected)
    let decodedFirst = try incoming.open(firstExpected)
    #expect(decodedFirst == first)
    var corrupt = secondExpected
    corrupt[corrupt.count - 1] ^= 1
    #expect(throws: BedrockError.invalidChecksum) { try incoming.open(corrupt) }
}

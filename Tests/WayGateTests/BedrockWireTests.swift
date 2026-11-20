@testable import WayGate
import Testing

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

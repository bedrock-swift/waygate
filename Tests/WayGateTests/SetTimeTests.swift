import Testing
import WayGate

@Test func encodesSignedWorldTime() throws {
    let cases: [(Int32, [UInt8])] = [
        (0, [0]), (-1, [1]), (24_000, [0x80, 0xf7, 2]), (.min, [0xff, 0xff, 0xff, 0xff, 0x0f]),
        (.max, [0xfe, 0xff, 0xff, 0xff, 0x0f])
    ]
    for (time, bytes) in cases {
        let packet = try BedrockPacket(id: 10, target: 1, payload: bytes)
        #expect(try SetTime(time: time).packet(target: 1) == packet)
        #expect(try SetTime(decoding: packet).time == time)
    }
}

@Test func rejectsMalformedWorldTime() throws {
    let truncated = try BedrockPacket(id: 10, payload: [0x80])
    #expect(throws: BedrockError.malformed) { try SetTime(decoding: truncated) }
    let extra = try BedrockPacket(id: 10, payload: [0, 0])
    #expect(throws: BedrockError.malformed) { try SetTime(decoding: extra) }
}

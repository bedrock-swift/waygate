@testable import WayGate
import Testing

@Test func encodesAndDecodesSetLocalPlayerAsInitialized() throws {
    let zero = SetLocalPlayerAsInitialized(entityRuntimeID: 0)
    #expect(zero.encode() == [0x00])
    #expect(try SetLocalPlayerAsInitialized(decoding: [0x00]) == zero)

    let large = SetLocalPlayerAsInitialized(entityRuntimeID: UInt64(UInt32.max) + 1)
    #expect(large.encode() == [0x80, 0x80, 0x80, 0x80, 0x10])
    #expect(try SetLocalPlayerAsInitialized(decoding: [0x80, 0x80, 0x80, 0x80, 0x10]) == large)

    let max = SetLocalPlayerAsInitialized(entityRuntimeID: UInt64.max)
    #expect(max.encode() == [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01])
    #expect(try SetLocalPlayerAsInitialized(decoding: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01]) == max)

    let packet = try large.packet()
    #expect(packet.id == 113)
    #expect(try SetLocalPlayerAsInitialized(decoding: packet) == large)
}

@Test func rejectsMalformedSetLocalPlayerAsInitialized() throws {
    #expect(throws: BedrockError.malformed) {
        try SetLocalPlayerAsInitialized(decoding: [])
    }
    #expect(throws: BedrockError.malformed) {
        try SetLocalPlayerAsInitialized(decoding: [0x80])
    }
    #expect(throws: BedrockError.malformed) {
        try SetLocalPlayerAsInitialized(decoding: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x02])
    }
    #expect(throws: BedrockError.malformed) {
        try SetLocalPlayerAsInitialized(decoding: [0x01, 0x00])
    }

    let wrongPacket = try BedrockPacket(id: 99, payload: [0x00])
    #expect(throws: BedrockError.unexpectedPacket(99)) {
        try SetLocalPlayerAsInitialized(decoding: wrongPacket)
    }
}

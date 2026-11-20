import Testing
import WayGate

@Test func resourcePackStackMatchesGophertunnel() throws {
    let wire: [UInt8] = [
        1, 1, 1, 0x62, 1, 0x31, 0, 1, 1, 0x74, 1, 0x32, 1, 0x73,
        7, 0x31, 0x2e, 0x32, 0x31, 0x2e, 0x39, 0x33,
        1, 0, 0, 0, 7, 0x65, 0x78, 0x61, 0x6d, 0x70, 0x6c, 0x65, 1, 1, 0
    ]
    let stack = ResourcePackStack(
        required: true, behaviorPacks: [.init(id: "b", version: "1")],
        texturePacks: [.init(id: "t", version: "2", subPackName: "s")], baseGameVersion: "1.21.93",
        experiments: [.init(name: "example", enabled: true)], experimentsPreviouslyToggled: true
    )
    let packet = try BedrockPacket(id: 7, payload: wire)
    #expect(try stack.packet() == packet)
    #expect(try ResourcePackStack(decoding: packet) == stack)

    for invalid: [UInt8] in [Array(wire.dropLast()), wire + [0], [0, 255, 255, 255, 255, 15]] {
        let packet = try BedrockPacket(id: 7, payload: invalid)
        #expect(throws: BedrockError.malformed) { try ResourcePackStack(decoding: packet) }
    }
}

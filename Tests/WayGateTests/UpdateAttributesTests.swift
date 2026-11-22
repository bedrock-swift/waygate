import Testing
import WayGate

@Test func encodesChangedAttributesWithDefaultsAndModifiers() throws {
    let modifier = UpdateAttributes.Modifier(id: "id", name: "name", amount: -0.5, operation: 2, operand: 1, serializable: true)
    let attribute = UpdateAttributes.Attribute(
        name: "minecraft:health", minimum: 0, maximum: 20, value: 16, defaultMinimum: 1,
        defaultMaximum: 19, defaultValue: 18, modifiers: [modifier]
    )
    let update = UpdateAttributes(runtimeID: 300, attributes: [attribute], tick: 301)
    let payload: [UInt8] = [
        0xac, 2, 1, 0, 0, 0, 0, 0, 0, 0xa0, 0x41, 0, 0, 0x80, 0x41,
        0, 0, 0x80, 0x3f, 0, 0, 0x98, 0x41, 0, 0, 0x90, 0x41, 16,
        0x6d, 0x69, 0x6e, 0x65, 0x63, 0x72, 0x61, 0x66, 0x74, 0x3a, 0x68, 0x65, 0x61, 0x6c, 0x74, 0x68,
        1, 2, 0x69, 0x64, 4, 0x6e, 0x61, 0x6d, 0x65, 0, 0, 0, 0xbf, 2, 0, 0, 0, 1, 0, 0, 0, 1, 0xad, 2
    ]
    let packet = try BedrockPacket(id: 29, payload: payload)
    #expect(try update.packet() == packet)
    #expect(try UpdateAttributes(decoding: packet) == update)
    let malformed = try BedrockPacket(id: 29, payload: Array(payload.dropLast()))
    #expect(throws: BedrockError.malformed) { try UpdateAttributes(decoding: malformed) }
}

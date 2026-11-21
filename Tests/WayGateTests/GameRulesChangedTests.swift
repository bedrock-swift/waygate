import Testing
import WayGate

@Test func encodesGameRuleValues() throws {
    let rules = GameRulesChanged(rules: [
        .init(name: "a", value: .unset),
        .init(name: "b", canBeModifiedByPlayer: true, value: .bool(true)),
        .init(name: "c", value: .integer(258)),
        .init(name: "d", value: .float(0.5))
    ])
    let bytes: [UInt8] = [
        4, 1, 97, 0, 0, 1, 98, 1, 1, 1, 1, 99, 0, 2, 2, 1, 0, 0, 1, 100, 0, 3, 0, 0, 0, 0x3f
    ]
    let packet = try BedrockPacket(id: 72, payload: bytes)
    #expect(try rules.packet() == packet)
    #expect(try GameRulesChanged(decoding: packet) == rules)
    let unknown = try BedrockPacket(id: 72, payload: [1, 0, 0, 4])
    #expect(throws: BedrockError.malformed) { try GameRulesChanged(decoding: unknown) }
}

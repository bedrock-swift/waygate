import Testing
import WayGate

@Test func encodesTextPacketsByCategory() throws {
    let fixtures: [(TextPacket, [UInt8])] = [
        (.init(kind: .system, message: "hi"), [0, 0, 6, 2, 104, 105, 0, 0, 0]),
        (
            .init(kind: .chat, message: "hi", sourceName: "p", xuid: "3", filteredMessage: "ok"),
            [0, 1, 1, 1, 112, 2, 104, 105, 1, 51, 0, 1, 2, 111, 107]
        ),
        (
            .init(kind: .translation, message: "m", needsTranslation: true, parameters: ["a", "b"]),
            [1, 2, 2, 1, 109, 2, 1, 97, 1, 98, 0, 0, 0]
        )
    ]
    for (text, payload) in fixtures {
        let packet = try BedrockPacket(id: 9, payload: payload)
        #expect(try text.packet() == packet)
        #expect(try TextPacket(decoding: packet) == text)
    }
}

@Test func rejectsInvalidTextCategoriesAndParameterCounts() throws {
    let wrongCategory = try BedrockPacket(id: 9, payload: [0, 1, 6, 2, 104, 105, 0, 0, 0])
    #expect(throws: BedrockError.malformed) { try TextPacket(decoding: wrongCategory) }

    let tooManyParameters = TextPacket(kind: .popup, message: "a", parameters: Array(repeating: "a", count: 5))
    #expect(throws: BedrockError.limitExceeded) { try tooManyParameters.packet() }
}

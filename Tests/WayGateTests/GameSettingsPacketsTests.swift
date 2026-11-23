import Testing
import WayGate

@Test func encodesDifficultyAndPlayerGameType() throws {
    let difficulty = SetDifficulty(difficulty: 3)
    let difficultyPacket = try BedrockPacket(id: 60, payload: [3])
    #expect(try difficulty.packet() == difficultyPacket)
    #expect(try SetDifficulty(decoding: difficultyPacket) == difficulty)

    let mode = SetPlayerGameType(gameType: 6)
    let modePacket = try BedrockPacket(id: 62, target: 1, payload: [12])
    #expect(try mode.packet(target: 1) == modePacket)
    #expect(try SetPlayerGameType(decoding: modePacket) == mode)
    #expect(throws: BedrockError.unexpectedPacket(60)) { try SetPlayerGameType(decoding: difficultyPacket) }
}

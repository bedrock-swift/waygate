import Foundation
import Testing
import WayGate

@Test func encodesEmoteAndEquippedPieces() throws {
    let id = UUID(uuid: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15))
    let list = EmoteList(runtimeID: 300, pieces: [id])
    let listPacket = try BedrockPacket(id: 152, payload: [172, 2, 1, 7, 6, 5, 4, 3, 2, 1, 0, 15, 14, 13, 12, 11, 10, 9, 8])
    #expect(try list.packet() == listPacket)
    #expect(try EmoteList(decoding: listPacket) == list)
    let truncated = try BedrockPacket(id: 152, payload: Array(listPacket.payload.dropLast()))
    #expect(throws: BedrockError.malformed) { try EmoteList(decoding: truncated) }

    let emote = Emote(runtimeID: 300, id: "e", length: 300, xuid: "1", flags: [.serverSide, .muteChat])
    let emotePacket = try BedrockPacket(id: 138, payload: [172, 2, 1, 101, 172, 2, 1, 49, 0, 3])
    #expect(try emote.packet() == emotePacket)
    #expect(try Emote(decoding: emotePacket) == emote)
}

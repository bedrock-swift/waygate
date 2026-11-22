import Testing
import WayGate

@Test func encodesTitleTextAndDurations() throws {
    let title = SetTitle(action: .actionBarTextObject, text: "{}", xuid: "1", platformOnlineID: "2", filteredMessage: "x")
    let titlePacket = try BedrockPacket(id: 88, sender: 2, target: 1, payload: [
        16, 2, 123, 125, 0, 0, 0, 1, 49, 1, 50, 1, 120
    ])
    #expect(try title.packet(sender: 2, target: 1) == titlePacket)
    #expect(try SetTitle(decoding: titlePacket) == title)

    let durations = SetTitle(action: .durations, fadeIn: 10, stay: 80, fadeOut: 20)
    let durationPacket = try BedrockPacket(id: 88, payload: [10, 0, 20, 160, 1, 40, 0, 0, 0])
    #expect(try durations.packet() == durationPacket)
    #expect(try SetTitle(decoding: durationPacket) == durations)
}

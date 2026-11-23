import Testing
import WayGate

@Test func decodesStackTransferAndAutoCraftActions() throws {
    let bytes: [UInt8] = [
        1, 5, 2,
        1, 1, 3, 27, 0, 4, 42, 0, 0, 0, 58, 1, 7, 0, 0, 0, 2, 0, 0, 0, 0,
        11, 13, 42, 2, 1, 3, 3, 3, 108, 111, 103, 3, 0,
        1, 1, 120, 2, 0, 0, 0
    ]
    let packet = try BedrockPacket(id: 147, payload: bytes)
    let request = try #require(try ItemStackRequest(decoding: packet).entries.first)
    #expect(request.requestID == -3)
    #expect(request.filterStrings == ["x"])
    #expect(request.filterCause == 2)
    #expect(request.actions.count == 2)
    guard case let .place(count, source, destination) = request.actions.first else {
        Issue.record("missing place action")
        return
    }
    #expect(count == 3)
    #expect(source.container == FullContainerName(id: 27))
    #expect(source.slot == 4)
    #expect(source.stackNetworkID == 42)
    #expect(destination.container == FullContainerName(id: 58, dynamicID: 7))
    guard case let .autoCraftRecipe(id, crafts, ingredients) = request.actions.last else {
        Issue.record("missing auto craft action")
        return
    }
    #expect(id == 42)
    #expect(crafts == 2)
    #expect(ingredients.first?.descriptor == .tag("log"))
    #expect(ingredients.first?.count == 3)

    let invalidVariant = try BedrockPacket(id: 147, payload: [1, 0, 1, 19, 21, 0, 0, 0, 0, 0])
    #expect(throws: BedrockError.malformed) { try ItemStackRequest(decoding: invalidVariant) }
}

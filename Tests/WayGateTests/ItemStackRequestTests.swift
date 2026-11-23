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
    let decoded = try ItemStackRequest(decoding: packet)
    #expect(try decoded.packet() == packet)
    let request = try #require(decoded.entries.first)
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

@Test func roundTripsEveryStackRequestAction() throws {
    let source = ItemStackRequest.Slot(container: .init(id: 27), slot: 2, stackNetworkID: 12)
    let destination = ItemStackRequest.Slot(container: .init(id: 58, dynamicID: 7), slot: 1, stackNetworkID: -1)
    let request = ItemStackRequest(entries: [
        .init(requestID: -3, actions: [
            .take(count: 2, source: source, destination: destination),
            .place(count: 2, source: source, destination: destination),
            .swap(source: source, destination: destination),
            .drop(count: 1, source: source, randomly: true),
            .destroy(count: 1, source: source),
            .consume(count: 1, source: source),
            .create(resultsSlot: 2),
            .labTableCombine,
            .beaconPayment(primary: -1, secondary: 2),
            .mineBlock(hotbarSlot: 1, predictedDurability: -2, stackNetworkID: 12),
            .craftRecipe(id: 42, count: 1),
            .autoCraftRecipe(id: 42, count: 1, ingredients: [
                .init(descriptor: .empty, count: 0),
                .init(descriptor: .item(name: "test:item", metadata: -1), count: 2),
                .init(descriptor: .molang(expression: "q.test", version: 1), count: 1),
                .init(descriptor: .tag("test:tag"), count: 1)
            ]),
            .craftCreative(id: 42, count: 1),
            .craftOptionalRecipe(id: 42, filterStringIndex: -1),
            .craftGrindstoneRecipe(id: 42, count: 2, cost: -3),
            .craftLoomRecipe(pattern: "test:pattern", count: 1),
            .craftReserved(id: "test:reserved", count: 1),
            .craftNotImplemented,
            .craftResults(items: [
                .init(count: 0, blockRuntimeID: 0),
                .init(identifier: "test:item", metadata: -1, count: 2, blockRuntimeID: 42)
            ], count: 2)
        ], filterStrings: ["name"], filterCause: -1)
    ])
    let packet = try request.packet(sender: 2, target: 1)
    #expect(packet.sender == 2)
    #expect(packet.target == 1)
    #expect(try ItemStackRequest(decoding: packet) == request)
}

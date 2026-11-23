import Testing
import WayGate

@Test func encodesAcceptedAndRejectedStackResponses() throws {
    let response = ItemStackResponse(entries: [
        .init(status: 0, requestID: -3, containers: [
            .init(name: .init(id: 27, dynamicID: 7), slots: [
                .init(slot: 2, hotbarSlot: 2, count: 4, stackNetworkID: 40, customName: "a",
                      filteredCustomName: "b", durabilityCorrection: -2)
            ])
        ]),
        .init(status: 1, requestID: 5)
    ])
    let payload: [UInt8] = [
        2, 0, 5, 1, 1, 27, 1, 7, 0, 0, 0, 1,
        2, 2, 4, 1, 80, 1, 97, 1, 1, 98, 3,
        1, 10, 0
    ]
    let packet = try BedrockPacket(id: 148, payload: payload)
    #expect(try response.packet() == packet)
    #expect(try ItemStackResponse(decoding: packet) == response)

    let truncated = try BedrockPacket(id: 148, payload: Array(payload.dropLast()))
    #expect(throws: BedrockError.malformed) { try ItemStackResponse(decoding: truncated) }
    let tooMany = try BedrockPacket(id: 148, payload: [0x81, 0x20])
    #expect(throws: BedrockError.limitExceeded) { try ItemStackResponse(decoding: tooMany) }
}

import Testing
import WayGate

@Test func encodesBlockActorDataAndEvents() throws {
    let position = SIMD3<Int32>(-2, -64, 3)
    let nbt: [UInt8] = [10, 0, 3, 1, 120, 4, 0]
    let update = BlockActorData(position: position, data: try NetworkNBT(bytes: nbt))
    let updatePacket = try BedrockPacket(id: 56, payload: [3, 127, 6] + nbt)
    #expect(try update.packet() == updatePacket)
    #expect(try BlockActorData(decoding: updatePacket) == update)

    let truncated = try BedrockPacket(id: 56, payload: Array(updatePacket.payload.dropLast()))
    #expect(throws: BedrockError.malformed) { try BlockActorData(decoding: truncated) }

    let event = BlockEvent(position: position, eventType: BlockEvent.chestState, eventData: 1)
    let eventPacket = try BedrockPacket(id: 26, target: 1, payload: [3, 127, 6, 2, 2])
    #expect(try event.packet(target: 1) == eventPacket)
    #expect(try BlockEvent(decoding: eventPacket) == event)
}

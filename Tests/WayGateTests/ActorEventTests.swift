import Testing
import WayGate

@Test func encodesActorEventsWithAndWithoutPosition() throws {
    let event = ActorEvent(runtimeID: 300, eventType: 2, eventData: -1, position: SIMD3(1, -2, 0))
    let packet = try BedrockPacket(id: 27, payload: [172, 2, 2, 1, 1, 0, 0, 128, 63, 0, 0, 0, 192, 0, 0, 0, 0])
    #expect(try event.packet() == packet)
    #expect(try ActorEvent(decoding: packet) == event)
    let noPosition = try BedrockPacket(id: 27, payload: [1, 2, 0, 0])
    #expect(try ActorEvent(decoding: noPosition) == ActorEvent(runtimeID: 1, eventType: 2))
}

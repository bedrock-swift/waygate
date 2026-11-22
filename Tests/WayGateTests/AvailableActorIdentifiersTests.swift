import Testing
import WayGate

@Test func encodesAvailableActorIdentifiersAsNetworkNBT() throws {
    let bytes: [UInt8] = [10, 0, 9, 6, 105, 100, 108, 105, 115, 116, 10, 0, 0]
    let identifiers = try NetworkNBT(bytes: bytes)
    let registry = AvailableActorIdentifiers(identifiers: identifiers)
    let packet = try BedrockPacket(id: 119, sender: 1, target: 2, payload: bytes)
    #expect(try registry.packet(sender: 1, target: 2) == packet)
    #expect(try AvailableActorIdentifiers(decoding: packet) == registry)
    #expect(try AvailableActorIdentifiers(names: []) == registry)

    let names = try AvailableActorIdentifiers(names: ["minecraft:player"])
    let expected = Array(bytes.dropLast(2)) + [2, 8, 2, 105, 100, 16] + Array("minecraft:player".utf8) + [0, 0]
    #expect(names.identifiers.bytes == expected)

    let truncated = try BedrockPacket(id: 119, payload: Array(bytes.dropLast()))
    #expect(throws: BedrockError.malformed) { try AvailableActorIdentifiers(decoding: truncated) }
}

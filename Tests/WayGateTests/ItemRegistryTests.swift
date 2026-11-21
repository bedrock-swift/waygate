import Testing
import WayGate

@Test func encodesItemRegistryAndItsCompoundBoundaries() throws {
    let components = try NetworkNBT(bytes: [10, 0, 3, 1, 120, 14, 0])
    let registry = ItemRegistry(items: [
        .init(name: "a", runtimeID: -2, componentBased: false, version: -1),
        .init(name: "b", runtimeID: 258, componentBased: true, version: 1, data: components)
    ])
    let wire: [UInt8] = [2, 1, 97, 0xfe, 0xff, 0, 1, 10, 0, 0, 1, 98, 2, 1, 1, 2, 10, 0, 3, 1, 120, 14, 0]
    let packet = try BedrockPacket(id: 162, target: 1, payload: wire)
    #expect(try registry.packet(target: 1) == packet)
    #expect(try ItemRegistry(decoding: packet) == registry)
    let truncated = try BedrockPacket(id: 162, payload: Array(wire.dropLast()))
    #expect(throws: BedrockError.malformed) { try ItemRegistry(decoding: truncated) }
}

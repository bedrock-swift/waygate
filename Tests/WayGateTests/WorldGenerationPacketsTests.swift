import Testing
import WayGate

@Test func encodesFeatureRegistryAndJigsawStructureData() throws {
    let registry = FeatureRegistry(features: [.init(name: "a", json: [123, 125])])
    let features = try BedrockPacket(id: 191, payload: [1, 1, 97, 2, 123, 125])
    #expect(try registry.packet() == features)
    #expect(try FeatureRegistry(decoding: features) == registry)
    let truncated = try BedrockPacket(id: 191, payload: [1, 1, 97, 2, 123])
    #expect(throws: BedrockError.malformed) { try FeatureRegistry(decoding: truncated) }

    let data = try NetworkNBT(bytes: [10, 0, 3, 1, 120, 14, 0])
    let structure = JigsawStructureData(structureData: data)
    let structures = try BedrockPacket(id: 213, payload: [10, 0, 3, 1, 120, 14, 0])
    #expect(try structure.packet() == structures)
    #expect(try JigsawStructureData(decoding: structures) == structure)
}

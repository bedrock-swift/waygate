import Testing
import WayGate

@Test func encodesBiomeDefinitionsWithSharedNamesAndTags() throws {
    let biomes = BiomeDefinitionList(definitions: [
        .init(
            name: "plains", temperature: 1, downfall: 0.5, depth: 0.25, scale: 0.125,
            mapWaterColor: 0xa544aff5, rain: true, tags: ["plains", "overworld"]
        ),
        .init(name: "desert", id: 2, temperature: 2, downfall: 0, depth: 0, scale: 0, mapWaterColor: 0, rain: false)
    ])
    let expected: [UInt8] = [
        2,
        0, 0, 255, 255, 0, 0, 128, 63, 0, 0, 0, 63, 0, 0, 0, 0, 0, 0, 128, 62, 0, 0, 0, 62,
        245, 175, 68, 165, 1, 1, 2, 0, 0, 2, 0, 0,
        1, 0, 2, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0,
        3, 6, 112, 108, 97, 105, 110, 115, 6, 100, 101, 115, 101, 114, 116,
        9, 111, 118, 101, 114, 119, 111, 114, 108, 100
    ]
    #expect(try biomes.packet() == BedrockPacket(id: 122, payload: expected))
}

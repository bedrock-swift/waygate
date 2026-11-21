import Foundation
import Testing
import WayGate

@Test func encodesCustomDimensionDefinitions() throws {
    let id = try #require(UUID(uuidString: "00112233-4455-6677-8899-aabbccddeeff"))
    let data = DimensionData(definitions: [.init(
        name: "a", minimumY: -64, heightRange: 384, generator: 1, dimensionType: 1000,
        packID: id, defaultBiome: "b", cloudHeight: 128, renderClouds: true
    )])
    let bytes: [UInt8] = [
        1, 1, 97, 0x7f, 0x80, 6, 2, 0xd0, 0x0f,
        0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0, 0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88,
        1, 98, 0x80, 2, 1
    ]
    let packet = try BedrockPacket(id: 180, payload: bytes)
    #expect(try data.packet() == packet)
    #expect(try DimensionData(decoding: packet) == data)

    let truncated = try BedrockPacket(id: 180, payload: Array(bytes.dropLast()))
    #expect(throws: BedrockError.malformed) { try DimensionData(decoding: truncated) }
}

import Testing
import WayGate

@Test func roundTripsCreativeGroupsAndItemStacks() throws {
    let item = ItemStack(networkID: -2, count: 64, metadata: 257, blockRuntimeID: -4)
    let creative = CreativeContent(groups: [.init(category: 1)], entries: [.init(id: 300, item: item, groupIndex: 0)])
    let bytes: [UInt8] = [
        1, 1, 0, 0, 0, 0, 0, 0, 0,
        1, 0xac, 2, 3, 64, 0, 0x81, 2, 7, 10,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ]
    let packet = try BedrockPacket(id: 145, payload: bytes)
    #expect(try creative.packet() == packet)
    #expect(try CreativeContent(decoding: packet) == creative)
    let badGroup = try BedrockPacket(id: 145, payload: Array(bytes.dropLast()) + [1])
    #expect(throws: BedrockError.malformed) { try CreativeContent(decoding: badGroup) }
}

import Testing
import WayGate

@Test func roundTripsInventorySnapshotWithDynamicContainer() throws {
    let stack = ItemStack(networkID: -2, count: 4, metadata: 1, blockRuntimeID: 128)
    let inventory = InventoryContent(
        windowID: 300, slots: [ItemInstance(stack: stack, stackNetworkID: -9)],
        container: FullContainerName(id: 4, dynamicID: 0)
    )
    let bytes: [UInt8] = [
        0xac, 2, 1, 0xfe, 0xff, 4, 0, 1, 1, 0x11, 0x80, 1, 10,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        4, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    ]
    let packet = try BedrockPacket(id: 49, payload: bytes)
    #expect(try inventory.packet() == packet)
    #expect(try InventoryContent(decoding: packet) == inventory)
    let truncated = try BedrockPacket(id: 49, payload: Array(bytes.dropLast()))
    #expect(throws: BedrockError.malformed) { try InventoryContent(decoding: truncated) }
}

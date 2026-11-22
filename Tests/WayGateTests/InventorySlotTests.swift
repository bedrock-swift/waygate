import Testing
import WayGate

@Test func encodesInventorySlotWithOptionalContainerAndStorage() throws {
    let item = ItemInstance(
        stack: ItemStack(networkID: -2, count: 4, metadata: 1, blockRuntimeID: 128), stackNetworkID: -9
    )
    let update = InventorySlot(
        windowID: 5, slot: 300, item: item, container: FullContainerName(id: 4, dynamicID: 0), storageItem: .empty
    )
    let payload: [UInt8] = [
        5, 0xac, 2, 1, 4, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
        0xfe, 0xff, 4, 0, 1, 1, 0x11, 0x80, 1, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ]
    let packet = try BedrockPacket(id: 50, payload: payload)
    #expect(try update.packet() == packet)
    #expect(try InventorySlot(decoding: packet) == update)

    var invalid = payload
    invalid[3] = 2
    let malformed = try BedrockPacket(id: 50, payload: invalid)
    #expect(throws: BedrockError.malformed) { try InventorySlot(decoding: malformed) }
}

import Testing
import WayGate

@Test func encodesEquipmentSlotAndEntityInteraction() throws {
    let equipment = MobEquipment(runtimeID: 300, item: .empty, inventorySlot: 2, hotbarSlot: 3, windowID: 0)
    let equipmentPacket = try BedrockPacket(id: 31, payload: [172, 2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 0])
    #expect(try equipment.packet() == equipmentPacket)
    #expect(try MobEquipment(decoding: equipmentPacket) == equipment)

    let interact = Interact(action: .mouseOverEntity, targetRuntimeID: 300, position: SIMD3(1, -2, 0))
    let interactPacket = try BedrockPacket(id: 33, payload: [4, 172, 2, 1, 0, 0, 128, 63, 0, 0, 0, 192, 0, 0, 0, 0])
    #expect(try interact.packet() == interactPacket)
    #expect(try Interact(decoding: interactPacket) == interact)
    let open = try BedrockPacket(id: 33, payload: [6, 0, 0])
    #expect(try Interact(decoding: open) == Interact(action: .openInventory, targetRuntimeID: 0))
}

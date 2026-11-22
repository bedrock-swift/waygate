import Testing
import WayGate

@Test func encodesPlayerAuthMovementWithWideFlagsAndTick() throws {
    let input = PlayerAuthInput(
        rotation: SIMD2(1, 2), position: SIMD3(3, 4, 5), move: SIMD2(6, 7), headYaw: 8, flags: [10, 65],
        inputMode: 2, playMode: 1, interactionModel: -1, interactionRotation: SIMD2(9, 10),
        tick: 300, delta: SIMD3(11, 12, 13), analogueMove: SIMD2(14, 15),
        cameraOrientation: SIMD3(16, 17, 18), rawMove: SIMD2(19, 20)
    )
    let payload: [UInt8] = [
        0, 0, 0x80, 0x3f, 0, 0, 0, 0x40, 0, 0, 0x40, 0x40, 0, 0, 0x80, 0x40,
        0, 0, 0xa0, 0x40, 0, 0, 0xc0, 0x40, 0, 0, 0xe0, 0x40, 0, 0, 0, 0x41,
        2, 20, 0x82, 1, 2, 1, 1, 0, 0, 0x10, 0x41, 0, 0, 0x20, 0x41, 0xac, 2,
        0, 0, 0x30, 0x41, 0, 0, 0x40, 0x41, 0, 0, 0x50, 0x41, 0, 0, 0, 0, 0,
        0, 0, 0x60, 0x41, 0, 0, 0x70, 0x41, 0, 0, 0x80, 0x41, 0, 0, 0x88, 0x41,
        0, 0, 0x90, 0x41, 0, 0, 0x98, 0x41, 0, 0, 0xa0, 0x41
    ]
    let packet = try BedrockPacket(id: 144, sender: 2, target: 1, payload: payload)
    #expect(try input.packet(sender: 2, target: 1) == packet)
    #expect(try PlayerAuthInput(decoding: packet) == input)

    var withVehicle = payload
    let optionalStart = payload.count - 28 - 5
    withVehicle.replaceSubrange(optionalStart..<(optionalStart + 5), with: [0, 0, 0, 0, 1, 6])
    let vehiclePacket = try BedrockPacket(id: 144, payload: withVehicle)
    let decoded = try PlayerAuthInput(decoding: vehiclePacket)
    #expect(decoded.optionalData == [0, 0, 0, 0, 1, 6])
    #expect(decoded.rawMove == input.rawMove)
    #expect(try decoded.packet() == vehiclePacket)

    #expect(try decoded.movementActions()?.predictedVehicleID == 3)
    #expect(try input.movementActions()?.blocks == nil)

    var withActions = payload
    let data: [UInt8] = [0, 0, 1, 1, 0, 1, 4, 6, 2, 1, 0, 0, 0x80, 0x3f, 0, 0, 0, 0x40, 1, 7]
    withActions.replaceSubrange(optionalStart..<(optionalStart + 5), with: data)
    let actionPacket = try BedrockPacket(id: 144, payload: withActions)
    let actions = try #require(try PlayerAuthInput(decoding: actionPacket).movementActions())
    let block = try #require(actions.blocks?.first)
    #expect(actions.blocks?.count == 1)
    #expect(block.action == 0)
    #expect(block.position == SIMD3(-1, 2, 3))
    #expect(block.face == 1)
    #expect(actions.vehicleRotation == SIMD2(1, 2))
    #expect(actions.predictedVehicleID == -4)

    withActions[optionalStart] = 1
    let inventoryPacket = try BedrockPacket(id: 144, payload: withActions)
    #expect(try PlayerAuthInput(decoding: inventoryPacket).movementActions() == nil)

    var duplicateFlag = payload
    duplicateFlag.replaceSubrange(34...35, with: [20])
    for invalid in [duplicateFlag, Array(payload.dropLast())] {
        let packet = try BedrockPacket(id: 144, payload: invalid)
        #expect(throws: BedrockError.malformed) { try PlayerAuthInput(decoding: packet) }
    }
}

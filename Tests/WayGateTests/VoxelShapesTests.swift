import Testing
import WayGate

@Test func encodesVoxelCellsCoordinatesAndNames() throws {
    let registry = VoxelShapes(
        shapes: [.init(size: SIMD3(1, 2, 3), cells: [42], xCoordinates: [0.5], yCoordinates: [], zCoordinates: [])],
        names: [.init(name: "a", id: 258)], customShapeCount: 1
    )
    let wire: [UInt8] = [1, 1, 2, 3, 1, 42, 1, 0, 0, 0, 0x3f, 0, 0, 1, 1, 97, 2, 1, 1, 0]
    let packet = try BedrockPacket(id: 237, payload: wire)
    #expect(try registry.packet() == packet)
    #expect(try VoxelShapes(decoding: packet) == registry)
    #expect(try VoxelShapes().packet().payload == [0, 0, 0, 0])
    let truncated = try BedrockPacket(id: 237, payload: Array(wire.dropLast()))
    #expect(throws: BedrockError.malformed) { try VoxelShapes(decoding: truncated) }
}

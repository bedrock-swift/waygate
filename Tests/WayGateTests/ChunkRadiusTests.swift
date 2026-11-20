import Testing
import WayGate

@Test func encodesChunkRadiusRequestAndUpdate() throws {
    let request = RequestChunkRadius(radius: 64, maximumRadius: 96)
    let requestPacket = try BedrockPacket(id: 69, sender: 1, payload: [0x80, 1, 96])
    #expect(try request.packet(sender: 1) == requestPacket)
    #expect(try RequestChunkRadius(decoding: requestPacket) == request)

    let update = ChunkRadiusUpdated(radius: 32)
    let updatePacket = try BedrockPacket(id: 70, target: 1, payload: [64])
    #expect(try update.packet(target: 1) == updatePacket)
    #expect(try ChunkRadiusUpdated(decoding: updatePacket) == update)

    let missingMaximum = try BedrockPacket(id: 69, payload: [16])
    #expect(throws: BedrockError.malformed) { try RequestChunkRadius(decoding: missingMaximum) }
    let extra = try BedrockPacket(id: 70, payload: [16, 1])
    #expect(throws: BedrockError.malformed) { try ChunkRadiusUpdated(decoding: extra) }
    #expect(throws: BedrockError.unexpectedPacket(69)) { try ChunkRadiusUpdated(decoding: requestPacket) }
}

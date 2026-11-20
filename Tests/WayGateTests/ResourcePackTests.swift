import Foundation
import Testing
import WayGate

@Test func resourcePackArchiveReturnsOnlyRequestedBytes() throws {
    let id = try #require(UUID(uuidString: "00112233-4455-6677-8899-aabbccddeeff"))
    let archive = try ResourcePackArchive(id: id, bytes: Data([0, 0x61, 0x62, 0x63])[1...], chunkSize: 2)
    let info = archive.dataInfo
    #expect(info.packID == "00112233-4455-6677-8899-aabbccddeeff")
    #expect(info.chunkCount == 2)
    #expect(info.size == 3)
    #expect(info.hash == [
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea, 0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c, 0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad
    ])
    let first = try archive.chunk(for: .init(packID: info.packID, index: 0))
    #expect(first.offset == 0)
    #expect(first.data == [0x61, 0x62])
    let last = try archive.chunk(for: .init(packID: info.packID, index: 1))
    #expect(last.offset == 2)
    #expect(last.data == [0x63])
    #expect(throws: ResourcePackTransferError.invalidChunkIndex) {
        try archive.chunk(for: .init(packID: info.packID, index: 2))
    }
    #expect(throws: ResourcePackTransferError.unexpectedPack) {
        try archive.chunk(for: .init(packID: "other", index: 0))
    }
    #expect(throws: ResourcePackTransferError.emptyArchive) {
        try ResourcePackArchive(id: id, bytes: Data())
    }
    #expect(throws: ResourcePackTransferError.invalidChunkSize) {
        try ResourcePackArchive(id: id, bytes: Data([1]), chunkSize: 4 * 1024 * 1024)
    }
}

@Test func encodesResourcePackTransferPackets() throws {
    let hash = Array(repeating: UInt8(42), count: 32)
    let info = ResourcePackDataInfo(packID: "p", chunkSize: 256, chunkCount: 2, size: 258, hash: hash, premium: true, packType: 6)
    let request = ResourcePackChunkRequest(packID: "p", index: 1)
    let chunk = ResourcePackChunkData(packID: "p", index: 1, offset: 256, data: [22, 49])
    let infoWire: [UInt8] = [1, 112, 0, 1, 0, 0, 2, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 32] + hash + [1, 6]
    let infoPacket = try BedrockPacket(id: 82, payload: infoWire)
    let requestPacket = try BedrockPacket(id: 84, payload: [1, 112, 1, 0, 0, 0])
    let chunkPacket = try BedrockPacket(id: 83, payload: [1, 112, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 22, 49])
    #expect(try info.packet() == infoPacket)
    #expect(try request.packet() == requestPacket)
    #expect(try chunk.packet() == chunkPacket)
    #expect(try ResourcePackDataInfo(decoding: infoPacket) == info)
    #expect(try ResourcePackChunkRequest(decoding: requestPacket) == request)
    #expect(try ResourcePackChunkData(decoding: chunkPacket) == chunk)

    let truncated = try BedrockPacket(id: 83, payload: Array(chunkPacket.payload.dropLast()))
    #expect(throws: BedrockError.malformed) { try ResourcePackChunkData(decoding: truncated) }
    let negativeIndex = try BedrockPacket(id: 84, payload: [1, 112, 255, 255, 255, 255])
    #expect(throws: BedrockError.malformed) { try ResourcePackChunkRequest(decoding: negativeIndex) }
}

@Test func preservesPackOrderAndExperiments() throws {
    let wire: [UInt8] = [
        1, 1, 1, 0x62, 1, 0x31, 0, 1, 1, 0x74, 1, 0x32, 1, 0x73,
        7, 0x31, 0x2e, 0x32, 0x31, 0x2e, 0x39, 0x33,
        1, 0, 0, 0, 7, 0x65, 0x78, 0x61, 0x6d, 0x70, 0x6c, 0x65, 1, 1, 0
    ]
    let stack = ResourcePackStack(
        required: true, behaviorPacks: [.init(id: "b", version: "1")],
        texturePacks: [.init(id: "t", version: "2", subPackName: "s")], baseGameVersion: "1.21.93",
        experiments: [.init(name: "example", enabled: true)], experimentsPreviouslyToggled: true
    )
    let packet = try BedrockPacket(id: 7, payload: wire)
    #expect(try stack.packet(format: .legacy) == packet)
    #expect(try ResourcePackStack(decoding: packet, format: .legacy) == stack)

    for invalid: [UInt8] in [Array(wire.dropLast()), wire + [0], [0, 255, 255, 255, 255, 15]] {
        let packet = try BedrockPacket(id: 7, payload: invalid)
        #expect(throws: BedrockError.malformed) { try ResourcePackStack(decoding: packet, format: .legacy) }
    }
}

@Test func encodesResourcePackMetadataAndTemplate() throws {
    let wire: [UInt8] = [
        1, 0, 1, 0, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0,
        0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88, 1, 0x76, 1, 0,
        0xef, 0xcd, 0xab, 0x89, 0x67, 0x45, 0x23, 1, 0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10,
        1, 0x31, 2, 1, 0, 0, 0, 0, 0, 0, 1, 0x6b, 1, 0x73, 1, 0x69, 1, 0, 1, 1, 0x75
    ]
    let template = try #require(UUID(uuidString: "00112233-4455-6677-8899-aabbccddeeff"))
    let pack = try #require(UUID(uuidString: "01234567-89ab-cdef-1020-304050607080"))
    let info = ResourcePacksInfo(
        required: true, hasScripts: true, worldTemplateID: template, worldTemplateVersion: "v",
        texturePacks: [.init(
            id: pack, version: "1", size: 258, contentKey: "k", subPackName: "s", contentIdentity: "i",
            hasScripts: true, rtxEnabled: true, downloadURL: "u"
        )]
    )
    let packet = try BedrockPacket(id: 6, payload: wire)
    #expect(try info.packet(format: .legacy) == packet)
    #expect(try ResourcePacksInfo(decoding: packet, format: .legacy) == info)
    #expect(try ResourcePacksInfo(decoding: ResourcePacksInfo().packet()).worldTemplateID == nil)

    let invalid = try BedrockPacket(id: 6, payload: Array(wire.dropLast()))
    #expect(throws: BedrockError.malformed) { try ResourcePacksInfo(decoding: invalid, format: .legacy) }
}

@Test func encodesCurrentResourcePackMetadataAndStack() throws {
    let info = ResourcePacksInfo(required: true)
    let metadata = try BedrockPacket(id: 6, payload: [1] + Array(repeating: 0, count: 21))
    #expect(try info.packet() == metadata)
    #expect(try ResourcePacksInfo(decoding: metadata) == info)

    let stack = ResourcePackStack(
        required: true, texturePacks: [.init(id: "t", version: "2", subPackName: "s")], baseGameVersion: "1.26.60"
    )
    let stackPacket = try BedrockPacket(id: 7, payload: [
        1, 1, 1, 0x74, 1, 0x32, 1, 0x73, 7, 0x31, 0x2e, 0x32, 0x36, 0x2e, 0x36, 0x30, 0, 0, 0, 0, 0, 0
    ])
    #expect(try stack.packet() == stackPacket)
    #expect(try ResourcePackStack(decoding: stackPacket) == stack)
}

@Test func includesPackIDsOnlyWhenTheClientRequestsPacks() throws {
    let request = ResourcePackClientResponse(status: .sendPacks, packIDs: ["a_1", "b_20"])
    let wire: [UInt8] = [
        1, 11, 0x64, 0x6f, 0x77, 0x6e, 0x6c, 0x6f, 0x61, 0x64, 0x69, 0x6e, 0x67, 2, 3, 0x61, 0x5f, 0x31,
        4, 0x62, 0x5f, 0x32, 0x30
    ]
    let transfer = try BedrockPacket(id: 8, payload: wire)
    #expect(try request.packet() == transfer)
    #expect(try ResourcePackClientResponse(decoding: transfer) == request)

    let completed = ResourcePackClientResponse(status: .completed)
    let completePacket = try completed.packet()
    #expect(completePacket.payload == [3, 25] + Array("resourcepackstackfinished".utf8))
    #expect(try ResourcePackClientResponse(decoding: completePacket) == completed)
    let invalid = try BedrockPacket(id: 8, payload: [3] + Array(wire.dropFirst()))
    #expect(throws: BedrockError.malformed) { try ResourcePackClientResponse(decoding: invalid) }
}

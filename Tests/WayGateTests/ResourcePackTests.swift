import Foundation
import Testing
import WayGate

@Test func resourcePackTransferMatchesGophertunnel() throws {
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
}

@Test func resourcePackStackMatchesGophertunnel() throws {
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
    #expect(try stack.packet() == packet)
    #expect(try ResourcePackStack(decoding: packet) == stack)

    for invalid: [UInt8] in [Array(wire.dropLast()), wire + [0], [0, 255, 255, 255, 255, 15]] {
        let packet = try BedrockPacket(id: 7, payload: invalid)
        #expect(throws: BedrockError.malformed) { try ResourcePackStack(decoding: packet) }
    }
}

@Test func resourcePacksInfoMatchesGophertunnel() throws {
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
    #expect(try info.packet() == packet)
    #expect(try ResourcePacksInfo(decoding: packet) == info)
    #expect(try ResourcePacksInfo(decoding: ResourcePacksInfo().packet()).worldTemplateID == nil)

    let invalid = try BedrockPacket(id: 6, payload: Array(wire.dropLast()))
    #expect(throws: BedrockError.malformed) { try ResourcePacksInfo(decoding: invalid) }
}

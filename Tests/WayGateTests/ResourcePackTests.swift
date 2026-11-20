import Foundation
import Testing
import WayGate

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

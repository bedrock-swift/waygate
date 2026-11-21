import Foundation
import Testing
import WayGate

@Test func encodesServerTransfer() throws {
    let transfer = Transfer(address: "example.org", port: 19142, reloadWorld: true)
    let wire = [11] + Array("example.org".utf8) + [0xc6, 0x4a, 1, 0]
    let packet = try BedrockPacket(id: 85, target: 1, payload: wire)
    #expect(try transfer.packet(target: 1) == packet)
    #expect(try Transfer(decoding: packet) == transfer)
    let truncated = try BedrockPacket(id: 85, payload: Array(wire.dropLast()))
    #expect(throws: BedrockError.malformed) { try Transfer(decoding: truncated) }
}

@Test func preservesTransferGatheringInformation() throws {
    let id = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    var gathering = ServerJoinInformation.Gathering(experienceID: id, experienceName: "Event", creatorID: "Host")
    gathering.targetID = id
    gathering.scenarioID = "lobby"
    let transfer = Transfer(address: "example.org", port: 19142, gathering: gathering)
    #expect(try Transfer(decoding: transfer.packet()) == transfer)
}

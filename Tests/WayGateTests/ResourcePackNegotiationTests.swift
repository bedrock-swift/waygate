import Foundation
import Testing
import WayGate

@Test func acceptsClientCacheStatusBeforeThePackResponse() throws {
    var exchange = try ResourcePackNegotiation(info: .init(), stack: .init(baseGameVersion: "1.26.60"))
    let status = try ClientCacheStatus(enabled: false).packet()
    #expect(status == (try BedrockPacket(id: 129, payload: [0])))
    #expect(throws: ResourcePackNegotiationError.unexpectedResponse) { try exchange.receive(status) }
    _ = try exchange.begin()
    let invalid = try BedrockPacket(id: 129, payload: [2])
    #expect(throws: BedrockError.malformed) { try exchange.receive(invalid) }
    #expect(try exchange.receive(status).isEmpty)
    #expect(exchange.clientCacheEnabled == false)
    #expect(throws: ResourcePackNegotiationError.unexpectedResponse) { try exchange.receive(status) }
}

@Test func servesRequestedPacksInOrderBeforeSendingTheStack() throws {
    let first = try makeArchive("11111111-1111-4111-8111-111111111111", bytes: [1, 2, 3, 4])
    let second = try makeArchive("22222222-2222-4222-8222-222222222222", bytes: [5, 6, 7])
    let info = ResourcePacksInfo(required: true, texturePacks: [first, second].map {
        .init(id: UUID(uuidString: $0.dataInfo.packID)!, version: "1.0.0", size: $0.dataInfo.size)
    })
    let firstID = first.dataInfo.packID
    let secondID = second.dataInfo.packID + "_1.0.0"
    let stack = ResourcePackStack(
        required: true, texturePacks: info.texturePacks.map { .init(id: $0.id.uuidString.lowercased(), version: $0.version) },
        baseGameVersion: "1.26.60"
    )
    var exchange = try ResourcePackNegotiation(info: info, stack: stack, archives: [first, second])
    #expect(try exchange.begin() == info.packet())

    let early = try ResourcePackClientResponse(status: .completed).packet()
    #expect(throws: ResourcePackNegotiationError.unexpectedResponse) { try exchange.receive(early) }
    let wrongVersion = try ResourcePackClientResponse(status: .sendPacks, packIDs: [firstID + "_2.0.0"]).packet()
    #expect(throws: ResourcePackTransferError.unexpectedPack) { try exchange.receive(wrongVersion) }

    let request = try ResourcePackClientResponse(status: .sendPacks, packIDs: [firstID, secondID]).packet()
    let firstInfo = try #require(try exchange.receive(request).first)
    #expect(try ResourcePackDataInfo(decoding: firstInfo) == first.dataInfo)

    let indexOne = try ResourcePackChunkRequest(packID: firstID, index: 1).packet()
    #expect(throws: ResourcePackTransferError.invalidChunkIndex) { try exchange.receive(indexOne) }
    let indexZero = try ResourcePackChunkRequest(packID: firstID, index: 0).packet()
    let firstChunk = try #require(try exchange.receive(indexZero).first)
    #expect(try ResourcePackChunkData(decoding: firstChunk).data == [1, 2])
    let firstEnd = try exchange.receive(indexOne)
    #expect(firstEnd.count == 2)
    #expect(try ResourcePackChunkData(decoding: firstEnd[0]).data == [3, 4])
    #expect(try ResourcePackDataInfo(decoding: firstEnd[1]).packID == secondID)

    let secondStart = try ResourcePackChunkRequest(packID: second.dataInfo.packID, index: 0).packet()
    let secondNext = try ResourcePackChunkRequest(packID: secondID, index: 1).packet()
    let secondChunk = try #require(try exchange.receive(secondStart).first)
    #expect(try ResourcePackChunkData(decoding: secondChunk).data == [5, 6])
    let lastChunk = try #require(try exchange.receive(secondNext).first)
    #expect(try ResourcePackChunkData(decoding: lastChunk).data == [7])

    let downloaded = try ResourcePackClientResponse(status: .allPacksDownloaded).packet()
    #expect(try exchange.receive(downloaded) == [stack.packet()])
    #expect(!exchange.isComplete)
    #expect(try exchange.receive(early).isEmpty)
    #expect(exchange.isComplete)
}

@Test func supportsCachedAndRefusedPacks() throws {
    let info = ResourcePacksInfo()
    let stack = ResourcePackStack(baseGameVersion: "1.26.60")
    let ready = try ResourcePackClientResponse(status: .allPacksDownloaded).packet()
    let completed = try ResourcePackClientResponse(status: .completed).packet()
    let refused = try ResourcePackClientResponse(status: .refused).packet()
    var exchange = try ResourcePackNegotiation(info: info, stack: stack)
    var refusedExchange = exchange
    _ = try exchange.begin()
    _ = try refusedExchange.begin()
    #expect(try exchange.receive(ready) == [stack.packet()])
    #expect(try exchange.receive(completed).isEmpty)
    #expect(exchange.isComplete)
    #expect(throws: ResourcePackNegotiationError.refused) { try refusedExchange.receive(refused) }
    #expect(!refusedExchange.isComplete)
}

private func makeArchive(_ id: String, bytes: [UInt8]) throws -> ResourcePackArchive {
    try ResourcePackArchive(id: #require(UUID(uuidString: id)), bytes: Data(bytes), chunkSize: 2)
}

import Testing
import WayGate

@Test func encodesLoadingScreenEvents() throws {
    let join = ServerBoundLoadingScreen(event: .start)
    let begin = try join.packet()
    #expect(begin.id == 312)
    #expect(begin.payload == [2, 0])
    #expect(try ServerBoundLoadingScreen(decoding: begin) == join)

    let dimension = ServerBoundLoadingScreen(event: .end, screenID: 0x12345678)
    let end = try dimension.packet()
    #expect(end.payload == [4, 1, 0x78, 0x56, 0x34, 0x12])
    #expect(try ServerBoundLoadingScreen(decoding: end) == dimension)
}

@Test func rejectsMalformedLoadingScreenEvents() throws {
    let inputs: [[UInt8]] = [[6, 0], [2], [2, 2], [4, 1, 1, 2, 3], [4, 0, 9]]
    for payload in inputs {
        let packet = try BedrockPacket(id: 312, payload: payload)
        #expect(throws: BedrockError.malformed) { try ServerBoundLoadingScreen(decoding: packet) }
    }
}

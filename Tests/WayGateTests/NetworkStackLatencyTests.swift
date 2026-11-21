import Testing
import WayGate

@Test func encodesNetworkLatencyTimestampAndResponseFlag() throws {
    let latency = NetworkStackLatency(timestamp: -256, needsResponse: true)
    let bytes: [UInt8] = [0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 1]
    let packet = try BedrockPacket(id: 115, payload: bytes)
    #expect(try latency.packet() == packet)
    #expect(try NetworkStackLatency(decoding: packet) == latency)
    let invalid = try BedrockPacket(id: 115, payload: Array(bytes.dropLast()) + [2])
    #expect(throws: BedrockError.malformed) { try NetworkStackLatency(decoding: invalid) }
}

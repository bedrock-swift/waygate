import Testing
import WayGate

@Test func encodesNetworkSettingsBeforeCompression() throws {
    let request = RequestNetworkSettings(protocolVersion: 2225)
    let requestPacket = try BedrockPacket(id: 193, payload: [0, 0, 8, 0xb1])
    #expect(try request.packet() == requestPacket)
    #expect(try RequestNetworkSettings(decoding: requestPacket) == request)

    let settings = NetworkSettings(
        compressionThreshold: 512, compression: .snappy, clientThrottle: true,
        clientThrottleThreshold: 12, clientThrottleScalar: 0.5
    )
    let bytes: [UInt8] = [0, 2, 1, 0, 1, 12, 0, 0, 0, 0x3f]
    let response = try BedrockPacket(id: 143, payload: bytes)
    #expect(try settings.packet() == response)
    #expect(try NetworkSettings(decoding: response) == settings)

    let truncated = try BedrockPacket(id: 143, payload: Array(bytes.dropLast()))
    #expect(throws: BedrockError.malformed) { try NetworkSettings(decoding: truncated) }
}

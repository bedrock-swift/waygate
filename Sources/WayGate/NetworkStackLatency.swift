public struct NetworkStackLatency: Equatable, Sendable {
    public static let packetID: UInt16 = 115
    public let timestamp: Int64
    public let needsResponse: Bool

    public init(timestamp: Int64, needsResponse: Bool) {
        self.timestamp = timestamp
        self.needsResponse = needsResponse
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        timestamp = Int64(bitPattern: try reader.littleEndian(UInt64.self))
        needsResponse = try reader.bool()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public static func response(to request: BedrockPacket) throws -> BedrockPacket? {
        let latency = try Self(decoding: request)
        guard latency.needsResponse else { return nil }
        return try Self(timestamp: latency.timestamp, needsResponse: false)
            .packet(sender: request.target, target: request.sender)
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendLittleEndian(timestamp)
        payload.append(needsResponse ? 1 : 0)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

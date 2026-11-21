public struct ChangeDimension: Equatable, Sendable {
    public static let packetID: UInt16 = 61

    public let dimension: Int32
    public let position: SIMD3<Float>
    public let respawn: Bool
    public let screenID: UInt32?

    public init(dimension: Int32, position: SIMD3<Float>, respawn: Bool = false, screenID: UInt32? = nil) {
        self.dimension = dimension
        self.position = position
        self.respawn = respawn
        self.screenID = screenID
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        dimension = try reader.varInt()
        position = try SIMD3(reader.float32(), reader.float32(), reader.float32())
        respawn = try reader.bool()
        screenID = try reader.optional { try $0.littleEndian(UInt32.self) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarInt(dimension)
        payload.appendLittleEndian(position.x.bitPattern)
        payload.appendLittleEndian(position.y.bitPattern)
        payload.appendLittleEndian(position.z.bitPattern)
        payload.append(respawn ? 1 : 0)
        payload.appendOptional(screenID) { $0.appendLittleEndian($1) }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

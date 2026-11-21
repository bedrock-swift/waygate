public struct SetActorMotion: Equatable, Sendable {
    public static let packetID: UInt16 = 40
    public let runtimeID: UInt64
    public let velocity: SIMD3<Float>
    public let tick: UInt64

    public init(runtimeID: UInt64, velocity: SIMD3<Float>, tick: UInt64 = 0) {
        self.runtimeID = runtimeID
        self.velocity = velocity
        self.tick = tick
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        runtimeID = try reader.varULong()
        velocity = try SIMD3(reader.float32(), reader.float32(), reader.float32())
        tick = try reader.varULong()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarULong(runtimeID)
        payload.appendLittleEndian(velocity.x.bitPattern)
        payload.appendLittleEndian(velocity.y.bitPattern)
        payload.appendLittleEndian(velocity.z.bitPattern)
        payload.appendVarULong(tick)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

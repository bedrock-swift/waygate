public struct MoveActorAbsolute: Equatable, Sendable {
    public static let packetID: UInt16 = 18
    public let runtimeID: UInt64
    public let flags: UInt8
    public let position: SIMD3<Float>
    public let rotationBytes: SIMD3<UInt8>

    public var rotationDegrees: SIMD3<Float> {
        SIMD3(Float(rotationBytes.x), Float(rotationBytes.y), Float(rotationBytes.z)) * (360 / 256)
    }

    public init(runtimeID: UInt64, flags: UInt8, position: SIMD3<Float>, rotationBytes: SIMD3<UInt8>) {
        self.runtimeID = runtimeID
        self.flags = flags
        self.position = position
        self.rotationBytes = rotationBytes
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        runtimeID = try reader.varULong()
        flags = try reader.byte()
        position = try SIMD3(reader.float32(), reader.float32(), reader.float32())
        rotationBytes = try SIMD3(reader.byte(), reader.byte(), reader.byte())
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarULong(runtimeID)
        payload.append(flags)
        payload.appendLittleEndian(position.x.bitPattern)
        payload.appendLittleEndian(position.y.bitPattern)
        payload.appendLittleEndian(position.z.bitPattern)
        payload.append(contentsOf: [rotationBytes.x, rotationBytes.y, rotationBytes.z])
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

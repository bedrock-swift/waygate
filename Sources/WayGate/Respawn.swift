public struct Respawn: Equatable, Sendable {
    public enum State: UInt8, Sendable {
        case searchingForSpawn = 0
        case readyToSpawn = 1
        case clientReadyToSpawn = 2
    }

    public static let packetID: UInt16 = 45
    public let position: SIMD3<Float>
    public let state: State
    public let runtimeID: UInt64

    public init(position: SIMD3<Float>, state: State, runtimeID: UInt64) {
        self.position = position
        self.state = state
        self.runtimeID = runtimeID
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        position = try SIMD3(reader.float32(), reader.float32(), reader.float32())
        guard let state = State(rawValue: try reader.byte()) else { throw BedrockError.malformed }
        self.state = state
        runtimeID = try reader.varULong()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendLittleEndian(position.x.bitPattern)
        payload.appendLittleEndian(position.y.bitPattern)
        payload.appendLittleEndian(position.z.bitPattern)
        payload.append(state.rawValue)
        payload.appendVarULong(runtimeID)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

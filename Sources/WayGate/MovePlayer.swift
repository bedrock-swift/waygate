public struct MovePlayer: Equatable, Sendable {
    public enum Mode: UInt8, Sendable {
        case normal = 0
        case respawn = 1
        case teleport = 2
        case headRotation = 3
    }

    public struct Teleport: Equatable, Sendable {
        public let cause: Int32
        public let sourceActorType: Int32

        public init(cause: Int32, sourceActorType: Int32) {
            self.cause = cause
            self.sourceActorType = sourceActorType
        }
    }

    public static let packetID: UInt16 = 19
    public let runtimeID: UInt64
    public let position: SIMD3<Float>
    public let pitch: Float
    public let yaw: Float
    public let headYaw: Float
    public let mode: Mode
    public let onGround: Bool
    public let riddenRuntimeID: UInt64
    public let teleport: Teleport?
    public let tick: UInt64

    public init(
        runtimeID: UInt64, position: SIMD3<Float>, pitch: Float, yaw: Float, headYaw: Float,
        mode: Mode = .normal, onGround: Bool = false, riddenRuntimeID: UInt64 = 0, teleport: Teleport? = nil,
        tick: UInt64
    ) {
        self.runtimeID = runtimeID
        self.position = position
        self.pitch = pitch
        self.yaw = yaw
        self.headYaw = headYaw
        self.mode = mode
        self.onGround = onGround
        self.riddenRuntimeID = riddenRuntimeID
        self.teleport = teleport
        self.tick = tick
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        runtimeID = try reader.varULong()
        position = try SIMD3(reader.float32(), reader.float32(), reader.float32())
        pitch = try reader.float32()
        yaw = try reader.float32()
        headYaw = try reader.float32()
        guard let mode = Mode(rawValue: try reader.byte()) else { throw BedrockError.malformed }
        self.mode = mode
        onGround = try reader.bool()
        riddenRuntimeID = try reader.varULong()
        teleport = try reader.optional {
            try Teleport(
                cause: Int32(bitPattern: $0.littleEndian(UInt32.self)),
                sourceActorType: Int32(bitPattern: $0.littleEndian(UInt32.self))
            )
        }
        tick = try reader.varULong()
        guard reader.isEmpty, mode == .teleport || teleport == nil else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard mode == .teleport || teleport == nil else { throw BedrockError.malformed }
        var payload: [UInt8] = []
        payload.appendVarULong(runtimeID)
        for value in [position.x, position.y, position.z, pitch, yaw, headYaw] {
            payload.appendLittleEndian(value.bitPattern)
        }
        payload.append(mode.rawValue)
        payload.append(onGround ? 1 : 0)
        payload.appendVarULong(riddenRuntimeID)
        payload.appendOptional(teleport) {
            $0.appendLittleEndian($1.cause)
            $0.appendLittleEndian($1.sourceActorType)
        }
        payload.appendVarULong(tick)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

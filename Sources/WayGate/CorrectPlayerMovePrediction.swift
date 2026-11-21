public struct CorrectPlayerMovePrediction: Equatable, Sendable {
    public enum Prediction: UInt8, Sendable {
        case player = 0
        case vehicle = 1
    }

    public static let packetID: UInt16 = 161
    public let prediction: Prediction
    public let position: SIMD3<Float>
    public let delta: SIMD3<Float>
    public let rotation: SIMD2<Float>
    public let vehicleAngularVelocity: Float?
    public let onGround: Bool
    public let tick: UInt64

    public init(
        prediction: Prediction, position: SIMD3<Float>, delta: SIMD3<Float>, rotation: SIMD2<Float> = .zero,
        vehicleAngularVelocity: Float? = nil, onGround: Bool, tick: UInt64
    ) {
        self.prediction = prediction
        self.position = position
        self.delta = delta
        self.rotation = rotation
        self.vehicleAngularVelocity = vehicleAngularVelocity
        self.onGround = onGround
        self.tick = tick
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        guard let prediction = Prediction(rawValue: try reader.byte()) else { throw BedrockError.malformed }
        self.prediction = prediction
        position = try SIMD3(reader.float32(), reader.float32(), reader.float32())
        delta = try SIMD3(reader.float32(), reader.float32(), reader.float32())
        rotation = try SIMD2(reader.float32(), reader.float32())
        vehicleAngularVelocity = try reader.optional { try $0.float32() }
        onGround = try reader.bool()
        tick = try reader.varULong()
        guard reader.isEmpty, prediction == .vehicle || vehicleAngularVelocity == nil else {
            throw BedrockError.malformed
        }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard prediction == .vehicle || vehicleAngularVelocity == nil else { throw BedrockError.malformed }
        var payload = [prediction.rawValue]
        for value in [position.x, position.y, position.z, delta.x, delta.y, delta.z, rotation.x, rotation.y] {
            payload.appendLittleEndian(value.bitPattern)
        }
        payload.appendOptional(vehicleAngularVelocity) { $0.appendLittleEndian($1.bitPattern) }
        payload.append(onGround ? 1 : 0)
        payload.appendVarULong(tick)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

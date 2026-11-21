public struct PlayerAction: Equatable, Sendable {
    public static let packetID: UInt16 = 36
    public static let dimensionChangeDone: Int32 = 14

    public let runtimeID: UInt64
    public let action: Int32
    public let blockPosition: SIMD3<Int32>
    public let resultPosition: SIMD3<Int32>
    public let blockFace: Int32

    public init(
        runtimeID: UInt64, action: Int32, blockPosition: SIMD3<Int32> = .zero,
        resultPosition: SIMD3<Int32> = .zero, blockFace: Int32 = 0
    ) {
        self.runtimeID = runtimeID
        self.action = action
        self.blockPosition = blockPosition
        self.resultPosition = resultPosition
        self.blockFace = blockFace
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        runtimeID = try reader.varULong()
        action = try reader.varInt()
        blockPosition = try reader.blockPosition()
        resultPosition = try reader.blockPosition()
        blockFace = try reader.varInt()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarULong(runtimeID)
        payload.appendVarInt(action)
        payload.appendBlockPosition(blockPosition)
        payload.appendBlockPosition(resultPosition)
        payload.appendVarInt(blockFace)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

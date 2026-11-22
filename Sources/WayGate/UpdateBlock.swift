public struct UpdateBlock: Equatable, Sendable {
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) { self.rawValue = rawValue }

        public static let neighbours = Flags(rawValue: 1 << 0)
        public static let network = Flags(rawValue: 1 << 1)
        public static let noGraphics = Flags(rawValue: 1 << 2)
        public static let priority = Flags(rawValue: 1 << 3)
    }

    public static let packetID: UInt16 = 21
    public let position: SIMD3<Int32>
    public let runtimeID: UInt32
    public let flags: Flags
    public let layer: UInt32

    public init(position: SIMD3<Int32>, runtimeID: UInt32, flags: Flags = .network, layer: UInt32 = 0) {
        self.position = position
        self.runtimeID = runtimeID
        self.flags = flags
        self.layer = layer
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        position = try reader.blockPosition()
        runtimeID = try reader.varUInt()
        flags = Flags(rawValue: try reader.varUInt())
        layer = try reader.varUInt()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendBlockPosition(position)
        payload.appendVarUInt(runtimeID)
        payload.appendVarUInt(flags.rawValue)
        payload.appendVarUInt(layer)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

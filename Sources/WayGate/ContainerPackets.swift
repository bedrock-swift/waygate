public struct ContainerOpen: Equatable, Sendable {
    public static let packetID: UInt16 = 46
    public let windowID: UInt8
    public let containerType: UInt8
    public let position: SIMD3<Int32>
    public let entityUniqueID: Int64

    public init(windowID: UInt8, containerType: UInt8, position: SIMD3<Int32>, entityUniqueID: Int64 = -1) {
        self.windowID = windowID
        self.containerType = containerType
        self.position = position
        self.entityUniqueID = entityUniqueID
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        windowID = try reader.byte()
        containerType = try reader.byte()
        position = try reader.blockPosition()
        let encoded = try reader.varULong()
        entityUniqueID = Int64(bitPattern: (encoded >> 1) ^ (0 &- (encoded & 1)))
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload = [windowID, containerType]
        payload.appendBlockPosition(position)
        payload.appendVarULong((UInt64(bitPattern: entityUniqueID) << 1) ^ UInt64(bitPattern: entityUniqueID >> 63))
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

public struct ContainerClose: Equatable, Sendable {
    public static let packetID: UInt16 = 47
    public let windowID: UInt8
    public let containerType: UInt8
    public let serverSide: Bool

    public init(windowID: UInt8, containerType: UInt8, serverSide: Bool) {
        self.windowID = windowID
        self.containerType = containerType
        self.serverSide = serverSide
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        windowID = try reader.byte()
        containerType = try reader.byte()
        serverSide = try reader.bool()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: [
            windowID, containerType, serverSide ? 1 : 0
        ])
    }
}

public struct RequestNetworkSettings: Equatable, Sendable {
    public static let packetID: UInt16 = 193
    public let protocolVersion: Int32

    public init(protocolVersion: Int32) {
        self.protocolVersion = protocolVersion
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        protocolVersion = try reader.protocolVersion()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet() throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendBigEndian(protocolVersion)
        return try BedrockPacket(id: Self.packetID, payload: payload)
    }
}

public struct NetworkSettings: Equatable, Sendable {
    public enum Compression: UInt16, Sendable {
        case zlib = 0
        case snappy = 1
        case none = 0xffff
    }

    public static let packetID: UInt16 = 143
    public let compressionThreshold: UInt16
    public let compression: Compression
    public let clientThrottle: Bool
    public let clientThrottleThreshold: UInt8
    public let clientThrottleScalar: Float

    public init(
        compressionThreshold: UInt16, compression: Compression, clientThrottle: Bool = false,
        clientThrottleThreshold: UInt8 = 0, clientThrottleScalar: Float = 0
    ) {
        self.compressionThreshold = compressionThreshold
        self.compression = compression
        self.clientThrottle = clientThrottle
        self.clientThrottleThreshold = clientThrottleThreshold
        self.clientThrottleScalar = clientThrottleScalar
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        compressionThreshold = try reader.littleEndian(UInt16.self)
        guard let compression = Compression(rawValue: try reader.littleEndian(UInt16.self)) else {
            throw BedrockError.malformed
        }
        self.compression = compression
        clientThrottle = try reader.bool()
        clientThrottleThreshold = try reader.byte()
        clientThrottleScalar = Float(bitPattern: try reader.littleEndian(UInt32.self))
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet() throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendLittleEndian(compressionThreshold)
        payload.appendLittleEndian(compression.rawValue)
        payload.append(clientThrottle ? 1 : 0)
        payload.append(clientThrottleThreshold)
        payload.appendLittleEndian(clientThrottleScalar.bitPattern)
        return try BedrockPacket(id: Self.packetID, payload: payload)
    }
}

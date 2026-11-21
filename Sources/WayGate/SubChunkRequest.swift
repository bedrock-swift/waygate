public struct SubChunkRequest: Equatable, Sendable {
    public static let packetID: UInt16 = 175
    private static let maximumOffsets: UInt32 = 8192

    public let dimension: Int32
    public let center: SIMD3<Int32>
    public let offsets: [SIMD3<Int8>]

    public init(dimension: Int32, center: SIMD3<Int32>, offsets: [SIMD3<Int8>]) {
        self.dimension = dimension
        self.center = center
        self.offsets = offsets
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        var reader = BedrockReader(packet.payload[...])
        dimension = try reader.varInt()
        let count = try reader.varUInt()
        guard count <= Self.maximumOffsets else { throw BedrockError.limitExceeded }
        offsets = try reader.list(count: count, minimumElementSize: 3) { try $0.subChunkOffset() }
        center = try reader.subChunkPosition()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard offsets.count <= Self.maximumOffsets else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendVarInt(dimension)
        payload.appendVarUInt(UInt32(offsets.count))
        for offset in offsets { payload.appendSubChunkOffset(offset) }
        payload.appendSubChunkPosition(center)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

extension BedrockReader {
    mutating func subChunkOffset() throws -> SIMD3<Int8> {
        try SIMD3(Int8(bitPattern: byte()), Int8(bitPattern: byte()), Int8(bitPattern: byte()))
    }

    mutating func subChunkPosition() throws -> SIMD3<Int32> {
        try SIMD3(
            Int32(bitPattern: littleEndian(UInt32.self)),
            Int32(bitPattern: littleEndian(UInt32.self)),
            Int32(bitPattern: littleEndian(UInt32.self))
        )
    }
}

extension [UInt8] {
    mutating func appendSubChunkOffset(_ offset: SIMD3<Int8>) {
        append(UInt8(bitPattern: offset.x))
        append(UInt8(bitPattern: offset.y))
        append(UInt8(bitPattern: offset.z))
    }

    mutating func appendSubChunkPosition(_ position: SIMD3<Int32>) {
        appendLittleEndian(position.x)
        appendLittleEndian(position.y)
        appendLittleEndian(position.z)
    }
}

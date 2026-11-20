public struct ResourcePackDataInfo: Equatable, Sendable {
    public static let packetID: UInt16 = 82
    public let packID: String
    public let chunkSize: UInt32
    public let chunkCount: UInt32
    public let size: UInt64
    public let hash: [UInt8]
    public let premium: Bool
    public let packType: UInt8

    public init(
        packID: String, chunkSize: UInt32, chunkCount: UInt32, size: UInt64,
        hash: [UInt8], premium: Bool = false, packType: UInt8
    ) {
        self.packID = packID
        self.chunkSize = chunkSize
        self.chunkCount = chunkCount
        self.size = size
        self.hash = hash
        self.premium = premium
        self.packType = packType
    }

    public init(decoding packet: BedrockPacket) throws {
        var reader = try resourcePackReader(packet, id: Self.packetID)
        packID = try reader.string()
        chunkSize = try reader.littleEndian(UInt32.self)
        chunkCount = try reader.littleEndian(UInt32.self)
        size = try reader.littleEndian(UInt64.self)
        hash = Array(try reader.varBytes())
        premium = try reader.bool()
        packType = try reader.byte()
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        try payload.appendString(packID)
        payload.appendLittleEndian(chunkSize)
        payload.appendLittleEndian(chunkCount)
        payload.appendLittleEndian(size)
        try payload.appendVarBytes(hash)
        payload.append(premium ? 1 : 0)
        payload.append(packType)
        return try resourcePackPacket(payload, id: Self.packetID, sender: sender, target: target)
    }
}

public struct ResourcePackChunkRequest: Equatable, Sendable {
    public static let packetID: UInt16 = 84
    public let packID: String
    public let index: UInt32

    public init(packID: String, index: UInt32) {
        self.packID = packID
        self.index = index
    }

    public init(decoding packet: BedrockPacket, format: ResourcePackFormat = .v26_60) throws {
        var reader = try resourcePackReader(packet, id: Self.packetID)
        packID = try reader.string()
        index = try reader.littleEndian(UInt32.self)
        guard reader.isEmpty, format == .legacy || index <= UInt32(Int32.max) else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0, format: ResourcePackFormat = .v26_60) throws -> BedrockPacket {
        guard format == .legacy || index <= UInt32(Int32.max) else { throw BedrockError.malformed }
        var payload: [UInt8] = []
        try payload.appendString(packID)
        payload.appendLittleEndian(index)
        return try resourcePackPacket(payload, id: Self.packetID, sender: sender, target: target)
    }
}

public struct ResourcePackChunkData: Equatable, Sendable {
    public static let packetID: UInt16 = 83
    public let packID: String
    public let index: UInt32
    public let offset: UInt64
    public let data: [UInt8]

    public init(packID: String, index: UInt32, offset: UInt64, data: [UInt8]) {
        self.packID = packID
        self.index = index
        self.offset = offset
        self.data = data
    }

    public init(decoding packet: BedrockPacket) throws {
        var reader = try resourcePackReader(packet, id: Self.packetID)
        packID = try reader.string()
        index = try reader.littleEndian(UInt32.self)
        offset = try reader.littleEndian(UInt64.self)
        data = Array(try reader.varBytes())
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        try payload.appendString(packID)
        payload.appendLittleEndian(index)
        payload.appendLittleEndian(offset)
        try payload.appendVarBytes(data)
        return try resourcePackPacket(payload, id: Self.packetID, sender: sender, target: target)
    }
}

private func resourcePackReader(_ packet: BedrockPacket, id: UInt16) throws -> BedrockReader {
    guard packet.id == id else { throw BedrockError.unexpectedPacket(packet.id) }
    guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
    return BedrockReader(packet.payload[...])
}

private func resourcePackPacket(_ payload: [UInt8], id: UInt16, sender: UInt8, target: UInt8) throws -> BedrockPacket {
    guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
    return try BedrockPacket(id: id, sender: sender, target: target, payload: payload)
}

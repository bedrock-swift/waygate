import Foundation

public struct EmoteList: Equatable, Sendable {
    public static let packetID: UInt16 = 152
    public let runtimeID: UInt64
    public let pieces: [UUID]

    public init(runtimeID: UInt64, pieces: [UUID]) {
        self.runtimeID = runtimeID
        self.pieces = pieces
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        runtimeID = try reader.varULong()
        let count = try reader.varUInt()
        pieces = try reader.list(count: count, minimumElementSize: 16) { try $0.uuid() }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarULong(runtimeID)
        guard pieces.count <= (BedrockBatch.maximumBytes - payload.count - 5) / 16 else {
            throw BedrockError.limitExceeded
        }
        payload.appendVarUInt(UInt32(pieces.count))
        for piece in pieces { payload.appendUUID(piece) }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

public struct Emote: Equatable, Sendable {
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let serverSide = Self(rawValue: 1 << 0)
        public static let muteChat = Self(rawValue: 1 << 1)
    }

    public static let packetID: UInt16 = 138
    public let runtimeID: UInt64
    public let id: String
    public let length: UInt32
    public let xuid: String
    public let platformID: String
    public let flags: Flags

    public init(runtimeID: UInt64, id: String, length: UInt32, xuid: String = "", platformID: String = "", flags: Flags = []) {
        self.runtimeID = runtimeID
        self.id = id
        self.length = length
        self.xuid = xuid
        self.platformID = platformID
        self.flags = flags
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        runtimeID = try reader.varULong()
        id = try reader.string()
        length = try reader.varUInt()
        xuid = try reader.string()
        platformID = try reader.string()
        flags = Flags(rawValue: try reader.byte())
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        var payload: [UInt8] = []
        payload.appendVarULong(runtimeID)
        try payload.appendString(id)
        payload.appendVarUInt(length)
        try payload.appendString(xuid)
        try payload.appendString(platformID)
        guard payload.count < BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        payload.append(flags.rawValue)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

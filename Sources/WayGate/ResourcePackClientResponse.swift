public struct ResourcePackClientResponse: Equatable, Sendable {
    public enum Status: UInt8, Sendable {
        case refused = 1
        case sendPacks
        case allPacksDownloaded
        case completed

        fileprivate var wireName: String {
            switch self {
            case .refused: "cancel"
            case .sendPacks: "downloading"
            case .allPacksDownloaded: "downloadingfinished"
            case .completed: "resourcepackstackfinished"
            }
        }
    }

    public static let packetID: UInt16 = 8
    public let status: Status
    public let packIDs: [String]

    public init(status: Status, packIDs: [String] = []) {
        self.status = status
        self.packIDs = packIDs
    }

    public init(decoding packet: BedrockPacket, format: ResourcePackFormat = .v26_60) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let status: Status
        let count: UInt32
        switch format {
        case .legacy:
            guard let value = Status(rawValue: try reader.byte()) else { throw BedrockError.malformed }
            status = value
            count = UInt32(try reader.littleEndian(UInt16.self))
        case .v26_60:
            let ordinal = try reader.varUInt()
            guard ordinal < 4, let value = Status(rawValue: UInt8(ordinal) + 1),
                  try reader.string() == value.wireName else { throw BedrockError.malformed }
            status = value
            count = status == .sendPacks ? try reader.varUInt() : 0
        }
        let packIDs = try reader.list(count: count, minimumElementSize: 1) { try $0.string() }
        guard reader.isEmpty else { throw BedrockError.malformed }
        self.init(status: status, packIDs: packIDs)
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0, format: ResourcePackFormat = .v26_60) throws -> BedrockPacket {
        var payload: [UInt8] = []
        switch format {
        case .legacy:
            guard let count = UInt16(exactly: packIDs.count) else { throw BedrockError.limitExceeded }
            payload.append(status.rawValue)
            payload.appendLittleEndian(count)
        case .v26_60:
            guard status == .sendPacks || packIDs.isEmpty else { throw BedrockError.malformed }
            payload.appendVarUInt(UInt32(status.rawValue - 1))
            try payload.appendString(status.wireName)
            if status == .sendPacks {
                guard let count = UInt32(exactly: packIDs.count) else { throw BedrockError.limitExceeded }
                payload.appendVarUInt(count)
            }
        }
        for id in packIDs { try payload.appendString(id) }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

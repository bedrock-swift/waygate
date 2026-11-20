import Foundation

public struct ResourcePackClientResponse: Equatable, Sendable {
    public enum Status: UInt8, Sendable {
        case refused = 1
        case sendPacks
        case allPacksDownloaded
        case completed
    }

    public static let packetID: UInt16 = 8
    public let status: Status
    public let packIDs: [String]

    public init(status: Status, packIDs: [String] = []) {
        self.status = status
        self.packIDs = packIDs
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        guard let status = Status(rawValue: try reader.byte()) else { throw BedrockError.malformed }
        let low = Int(try reader.byte())
        let count = low | (Int(try reader.byte()) << 8)
        guard count <= reader.remaining else { throw BedrockError.malformed }

        var packIDs: [String] = []
        packIDs.reserveCapacity(count)
        for _ in 0..<count {
            guard let length = Int(exactly: try reader.varUInt()),
                  let id = String(bytes: try reader.read(length), encoding: .utf8) else { throw BedrockError.malformed }
            packIDs.append(id)
        }
        guard reader.isEmpty else { throw BedrockError.malformed }
        self.init(status: status, packIDs: packIDs)
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let count = UInt16(exactly: packIDs.count) else { throw BedrockError.limitExceeded }
        var payload = [status.rawValue, UInt8(truncatingIfNeeded: count), UInt8(count >> 8)]
        for id in packIDs {
            let bytes = id.utf8
            guard bytes.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
            payload.appendVarUInt(UInt32(bytes.count))
            guard bytes.count <= BedrockBatch.maximumBytes - payload.count else { throw BedrockError.limitExceeded }
            payload.append(contentsOf: bytes)
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

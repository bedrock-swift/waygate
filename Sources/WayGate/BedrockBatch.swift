public struct BedrockPacket: Equatable, Sendable {
    public let id: UInt16
    public let sender: UInt8
    public let target: UInt8
    public let payload: [UInt8]

    public init(id: UInt16, sender: UInt8 = 0, target: UInt8 = 0, payload: [UInt8] = []) throws {
        guard id < 1024, sender < 4, target < 4 else { throw BedrockError.malformed }
        self.id = id
        self.sender = sender
        self.target = target
        self.payload = payload
    }
}

public enum BedrockBatch {
    public enum Framing: Equatable, Sendable {
        case initial
        case negotiated
    }

    public enum Transport: Equatable, Sendable {
        case raknet
        case nethernet
    }

    static let maximumBytes = 4 * 1024 * 1024
    static let compressionThreshold = 512
    private static let maximumPackets = 512

    public static func encode(
        _ packets: [BedrockPacket], framing: Framing = .initial, transport: Transport = .raknet
    ) throws -> [UInt8] {
        guard !packets.isEmpty, packets.count <= maximumPackets else { throw BedrockError.limitExceeded }
        let marker: [UInt8] = transport == .raknet ? [0xfe] : []
        var bytes = marker
        if framing == .negotiated { bytes.append(0xff) }
        let prefixLength = bytes.count
        for packet in packets {
            var header: [UInt8] = []
            header.appendVarUInt(UInt32(packet.id) | (UInt32(packet.sender) << 10) | (UInt32(packet.target) << 12))
            guard packet.payload.count <= maximumBytes - bytes.count - header.count else {
                throw BedrockError.limitExceeded
            }
            bytes.appendVarUInt(UInt32(header.count + packet.payload.count))
            guard bytes.count + header.count + packet.payload.count <= maximumBytes else {
                throw BedrockError.limitExceeded
            }
            bytes += header
            bytes += packet.payload
        }
        if framing == .negotiated, bytes.count - prefixLength >= compressionThreshold {
            let compressed = Snappy.encode(Array(bytes.dropFirst(prefixLength)))
            if compressed.count < bytes.count - prefixLength { return marker + [1] + compressed }
        }
        return bytes
    }

    public static func decode(
        _ bytes: [UInt8], framing: Framing = .initial, transport: Transport = .raknet
    ) throws -> [BedrockPacket] {
        guard bytes.count <= maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(bytes[...])
        if transport == .raknet, try reader.byte() != 0xfe { throw BedrockError.malformed }
        if framing == .negotiated {
            let algorithm = try reader.byte()
            switch algorithm {
            case 0xff: break
            case 1:
                let compressed = try reader.read(reader.remaining)
                reader = BedrockReader(try Snappy.decode(compressed, limit: maximumBytes)[...])
            default:
                throw BedrockError.unsupportedCompression(algorithm)
            }
        }
        var packets: [BedrockPacket] = []
        while !reader.isEmpty {
            guard packets.count < maximumPackets else { throw BedrockError.limitExceeded }
            guard let size = Int(exactly: try reader.varUInt()) else { throw BedrockError.malformed }
            let bytes = try reader.read(size)
            var packet = BedrockReader(bytes)
            let header = try packet.varUInt()
            guard header < (1 << 14) else { throw BedrockError.malformed }
            packets.append(try BedrockPacket(
                id: UInt16(header & 1023), sender: UInt8((header >> 10) & 3),
                target: UInt8((header >> 12) & 3), payload: Array(packet.read(packet.remaining))
            ))
        }
        guard !packets.isEmpty else { throw BedrockError.malformed }
        return packets
    }
}

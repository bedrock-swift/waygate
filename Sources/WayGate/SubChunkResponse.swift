public struct SubChunkResponse: Equatable, Sendable {
    public enum Status: UInt8, Sendable {
        case success = 1
        case chunkNotFound = 2
        case wrongDimension = 3
        case playerNotFound = 4
        case indexOutOfBounds = 5
        case allAir = 6
    }

    public enum HeightMap: Equatable, Sendable {
        case none
        case heights([Int8]) // z then x
        case tooHigh
        case tooLow
        case copied

        fileprivate init(reading reader: inout BedrockReader, render: Bool) throws {
            let kind = try reader.byte()
            guard try reader.bool() == (kind == 1) else { throw BedrockError.malformed }
            switch kind {
            case 0: self = .none
            case 1:
                var heights: [Int8] = []
                heights.reserveCapacity(256)
                for _ in 0..<16 {
                    guard try reader.varUInt() == 16 else { throw BedrockError.malformed }
                    heights.append(contentsOf: try reader.read(16).map { Int8(bitPattern: $0) })
                }
                self = .heights(heights)
            case 2: self = .tooHigh
            case 3: self = .tooLow
            case 4 where render: self = .copied
            default: throw BedrockError.malformed
            }
        }

        fileprivate func append(to payload: inout [UInt8], render: Bool) throws {
            switch self {
            case .none: payload += [0, 0]
            case .heights(let heights):
                guard heights.count == 256 else { throw BedrockError.malformed }
                payload += [1, 1]
                for start in stride(from: 0, to: 256, by: 16) {
                    payload.append(16)
                    payload.append(contentsOf: heights[start..<(start + 16)].map { UInt8(bitPattern: $0) })
                }
            case .tooHigh: payload += [2, 0]
            case .tooLow: payload += [3, 0]
            case .copied:
                guard render else { throw BedrockError.malformed }
                payload += [4, 0]
            }
        }
    }

    public struct Entry: Equatable, Sendable {
        public let offset: SIMD3<Int8>
        public let status: Status
        public let data: [UInt8]?
        public let heightMap: HeightMap
        public let renderHeightMap: HeightMap
        public let blobHash: UInt64?

        public init(
            offset: SIMD3<Int8>, status: Status, data: [UInt8]? = nil, heightMap: HeightMap = .none,
            renderHeightMap: HeightMap = .none, blobHash: UInt64? = nil
        ) {
            self.offset = offset
            self.status = status
            self.data = data
            self.heightMap = heightMap
            self.renderHeightMap = renderHeightMap
            self.blobHash = blobHash
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            offset = try reader.subChunkOffset()
            guard let status = Status(rawValue: try reader.byte()) else { throw BedrockError.malformed }
            self.status = status
            data = try reader.bool() ? Array(reader.varBytes()) : nil
            heightMap = try HeightMap(reading: &reader, render: false)
            renderHeightMap = try HeightMap(reading: &reader, render: true)
            blobHash = try reader.bool() ? reader.littleEndian(UInt64.self) : nil
        }

        fileprivate func append(to payload: inout [UInt8]) throws {
            payload.appendSubChunkOffset(offset)
            payload.append(status.rawValue)
            payload.append(data == nil ? 0 : 1)
            if let data {
                guard data.count <= BedrockBatch.maximumBytes - payload.count else { throw BedrockError.limitExceeded }
                try payload.appendVarBytes(data)
            }
            try heightMap.append(to: &payload, render: false)
            try renderHeightMap.append(to: &payload, render: true)
            payload.append(blobHash == nil ? 0 : 1)
            if let blobHash { payload.appendLittleEndian(blobHash) }
        }
    }

    public static let packetID: UInt16 = 174
    private static let maximumEntries: UInt32 = 8192

    public let cacheEnabled: Bool
    public let dimension: Int32
    public let center: SIMD3<Int32>
    public let entries: [Entry]

    public init(cacheEnabled: Bool = false, dimension: Int32, center: SIMD3<Int32>, entries: [Entry]) {
        self.cacheEnabled = cacheEnabled
        self.dimension = dimension
        self.center = center
        self.entries = entries
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        cacheEnabled = try reader.bool()
        dimension = try reader.varInt()
        center = try reader.subChunkPosition()
        let count = try reader.varUInt()
        guard count <= Self.maximumEntries else { throw BedrockError.limitExceeded }
        entries = try reader.list(count: count, minimumElementSize: 10) { try Entry(reading: &$0) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard entries.count <= Self.maximumEntries else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = [cacheEnabled ? 1 : 0]
        payload.appendVarInt(dimension)
        payload.appendSubChunkPosition(center)
        payload.appendVarUInt(UInt32(entries.count))
        for entry in entries {
            try entry.append(to: &payload)
            guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

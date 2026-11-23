extension [UInt8] {
    mutating func appendCompound(_ compound: NetworkNBT) throws {
        guard compound.bytes.count <= BedrockBatch.maximumBytes - count else { throw BedrockError.limitExceeded }
        append(contentsOf: compound.bytes)
    }
}

public struct NetworkNBT: Equatable, Sendable {
    public static let empty = NetworkNBT(validated: [10, 0, 0])
    public let bytes: [UInt8]

    public init(bytes: [UInt8]) throws {
        guard bytes.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(bytes[...])
        try Self.readRoot(&reader)
        guard reader.isEmpty else { throw BedrockError.malformed }
        self.init(validated: bytes)
    }

    init(reading reader: inout BedrockReader) throws {
        var scan = reader
        try Self.readRoot(&scan)
        self.init(validated: Array(try reader.read(reader.remaining - scan.remaining)))
    }

    private init(validated bytes: [UInt8]) {
        self.bytes = bytes
    }

    private enum Tag: UInt8 {
        case end, byte, short, int, long, float, double, byteArray, string, list, compound, intArray, longArray
    }

    private static func readRoot(_ reader: inout BedrockReader) throws {
        guard try readTag(&reader) == .compound else { throw BedrockError.malformed }
        _ = try reader.varBytes()
        try skip(.compound, in: &reader, depth: 0)
    }

    private static func readTag(_ reader: inout BedrockReader) throws -> Tag {
        guard let tag = Tag(rawValue: try reader.byte()) else { throw BedrockError.malformed }
        return tag
    }

    private static func readCount(_ reader: inout BedrockReader) throws -> Int {
        let count = try reader.varInt()
        guard count >= 0, let length = Int(exactly: count), length <= reader.remaining else {
            throw BedrockError.malformed
        }
        return length
    }

    private static func skip(_ tag: Tag, in reader: inout BedrockReader, depth: Int) throws {
        guard depth <= 64 else { throw BedrockError.limitExceeded }
        switch tag {
        case .end:
            throw BedrockError.malformed
        case .byte:
            _ = try reader.byte()
        case .short:
            _ = try reader.read(2)
        case .int:
            _ = try reader.varInt()
        case .long:
            try skipLong(&reader)
        case .float:
            _ = try reader.read(4)
        case .double:
            _ = try reader.read(8)
        case .byteArray:
            let count = try readCount(&reader)
            _ = try reader.read(count)
        case .string:
            _ = try reader.varBytes()
        case .list:
            let item = try readTag(&reader)
            let count = try readCount(&reader)
            guard item != .end || count == 0 else { throw BedrockError.malformed }
            for _ in 0..<count { try skip(item, in: &reader, depth: depth + 1) }
        case .compound:
            while true {
                let child = try readTag(&reader)
                if child == .end { return }
                _ = try reader.varBytes()
                try skip(child, in: &reader, depth: depth + 1)
            }
        case .intArray:
            let count = try readCount(&reader)
            for _ in 0..<count { _ = try reader.varInt() }
        case .longArray:
            let count = try readCount(&reader)
            for _ in 0..<count { try skipLong(&reader) }
        }
    }

    private static func skipLong(_ reader: inout BedrockReader) throws {
        for index in 0..<10 {
            let byte = try reader.byte()
            guard index < 9 || byte <= 1 else { throw BedrockError.malformed }
            if byte < 128 { return }
        }
        throw BedrockError.malformed
    }
}

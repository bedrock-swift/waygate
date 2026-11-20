enum Snappy {
    static func encode(_ bytes: [UInt8]) -> [UInt8] {
        var result: [UInt8] = []
        result.appendVarUInt(UInt32(bytes.count))
        var previous = [Int](repeating: -1, count: 16_384)
        var literalStart = 0
        var index = 0
        while index + 4 <= bytes.count {
            let word = word(at: index, in: bytes)
            let slot = Int((word &* 0x1e35_a7bd) >> 18)
            let candidate = previous[slot]
            previous[slot] = index
            guard candidate >= 0, index - candidate <= 65_535, word == self.word(at: candidate, in: bytes) else {
                index += 1
                continue
            }

            appendLiteral(bytes[literalStart..<index], to: &result)
            var length = 4
            while index + length < bytes.count, bytes[candidate + length] == bytes[index + length] {
                length += 1
            }
            let offset = index - candidate
            var remaining = length
            while remaining > 0 {
                let count = min(remaining, 64)
                result += [UInt8((count - 1) << 2) | 2, UInt8(offset & 255), UInt8(offset >> 8)]
                remaining -= count
            }
            index += length
            literalStart = index
        }
        appendLiteral(bytes[literalStart...], to: &result)
        return result
    }

    private static func word(at i: Int, in bytes: [UInt8]) -> UInt32 {
        UInt32(bytes[i]) | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2]) << 16 | UInt32(bytes[i + 3]) << 24
    }

    private static func appendLiteral(_ bytes: ArraySlice<UInt8>, to output: inout [UInt8]) {
        guard !bytes.isEmpty else { return }
        var length = bytes.count - 1
        if length < 60 {
            output.append(UInt8(length << 2))
        } else {
            let count = (Int.bitWidth - length.leadingZeroBitCount + 7) / 8
            output.append(UInt8((59 + count) << 2))
            for _ in 0..<count {
                output.append(UInt8(length & 255))
                length >>= 8
            }
        }
        output.append(contentsOf: bytes)
    }

    static func decode(_ data: ArraySlice<UInt8>, limit: Int) throws -> [UInt8] {
        var reader = BedrockReader(data)
        guard let size = Int(exactly: try reader.varUInt()), size <= limit else {
            throw BedrockError.limitExceeded
        }
        var output: [UInt8] = []
        while !reader.isEmpty {
            let tag = try reader.byte()
            switch tag & 3 {
            case 0:
                let length = Int(tag >> 2)
                let encoded = length < 60 ? UInt32(length) : try integer(from: &reader, bytes: length - 59)
                guard let count = Int(exactly: UInt64(encoded) + 1), count <= size - output.count else {
                    throw BedrockError.malformed
                }
                output.append(contentsOf: try reader.read(count))
            case 1:
                let length = 4 + Int((tag >> 2) & 7)
                let offset = Int(tag & 0xe0) << 3 | Int(try reader.byte())
                try copy(length, from: UInt32(offset), size: size, into: &output)
            case 2:
                try copy(1 + Int(tag >> 2), from: integer(from: &reader, bytes: 2), size: size, into: &output)
            default:
                try copy(1 + Int(tag >> 2), from: integer(from: &reader, bytes: 4), size: size, into: &output)
            }
        }
        guard output.count == size else { throw BedrockError.malformed }
        return output
    }

    private static func integer(from reader: inout BedrockReader, bytes: Int) throws -> UInt32 {
        try reader.read(bytes).enumerated().reduce(UInt32(0)) { $0 | (UInt32($1.element) << ($1.offset * 8)) }
    }

    private static func copy(_ count: Int, from distance: UInt32, size: Int, into output: inout [UInt8]) throws {
        guard let offset = Int(exactly: distance), offset > 0, offset <= output.count,
              count <= size - output.count else { throw BedrockError.malformed }
        for _ in 0..<count {
            let byte = output[output.count - offset]
            output.append(byte)
        }
    }
}

public enum BedrockError: Error, Equatable {
    case malformed
    case limitExceeded
    case unsupportedCompression(UInt8)
    case unexpectedPacket(UInt16)
    case unsupportedProtocol(Int32)
    case closed
    case timedOut
    case invalidChecksum
    case invalidClientToken
    case invalidIdentity
    case untrustedIdentity
    case expiredIdentity
    case concurrentOperation
}

struct BedrockReader {
    private var bytes: ArraySlice<UInt8>

    init(_ bytes: ArraySlice<UInt8>) { self.bytes = bytes }
    var isEmpty: Bool { bytes.isEmpty }
    var remaining: Int { bytes.count }

    mutating func read(_ count: Int) throws -> ArraySlice<UInt8> {
        guard count >= 0, count <= bytes.count else { throw BedrockError.malformed }
        let prefix = bytes.prefix(count)
        bytes = bytes.dropFirst(count)
        return prefix
    }

    mutating func varUInt() throws -> UInt32 {
        var value: UInt32 = 0
        for shift in stride(from: 0, through: 28, by: 7) {
            let byte = try byte()
            guard shift < 28 || byte < 16 else { throw BedrockError.malformed }
            value |= UInt32(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return value }
        }
        throw BedrockError.malformed
    }

    mutating func byte() throws -> UInt8 {
        guard let value = bytes.first else { throw BedrockError.malformed }
        bytes = bytes.dropFirst()
        return value
    }

    mutating func bool() throws -> Bool {
        let value = try byte()
        guard value <= 1 else { throw BedrockError.malformed }
        return value == 1
    }

    mutating func littleEndian<T: FixedWidthInteger & UnsignedInteger>(_ type: T.Type) throws -> T {
        try read(MemoryLayout<T>.size).enumerated().reduce(T.zero) {
            $0 | (T($1.element) << ($1.offset * 8))
        }
    }

    mutating func string() throws -> String {
        guard let count = Int(exactly: try varUInt()),
              let value = String(validating: try read(count), as: UTF8.self) else { throw BedrockError.malformed }
        return value
    }

    mutating func list<T>(
        count: UInt32, minimumElementSize: Int, decode: (inout Self) throws -> T
    ) throws -> [T] {
        guard let count = Int(exactly: count), count <= remaining / minimumElementSize else {
            throw BedrockError.malformed
        }
        var elements: [T] = []
        for _ in 0..<count { elements.append(try decode(&self)) }
        return elements
    }

    mutating func protocolVersion() throws -> Int32 {
        Int32(bitPattern: try read(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
    }

    mutating func loginField() throws -> ArraySlice<UInt8> {
        let size = try read(4).enumerated().reduce(UInt32(0)) { $0 | (UInt32($1.element) << ($1.offset * 8)) }
        guard size > 0, let count = Int(exactly: size) else { throw BedrockError.malformed }
        return try read(count)
    }
}

extension [UInt8] {
    mutating func appendVarUInt(_ value: UInt32) {
        var remaining = value
        while remaining >= 128 {
            append(UInt8(remaining & 127) | 128)
            remaining >>= 7
        }
        append(UInt8(remaining))
    }

    mutating func appendBigEndian(_ value: Int32) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendString(_ value: String) throws {
        let bytes = value.utf8
        guard bytes.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        appendVarUInt(UInt32(bytes.count))
        guard bytes.count <= BedrockBatch.maximumBytes - count else { throw BedrockError.limitExceeded }
        append(contentsOf: bytes)
    }
}

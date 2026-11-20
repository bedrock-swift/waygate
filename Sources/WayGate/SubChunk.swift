public struct SubChunk: Equatable, Sendable {
    private static let version: UInt8 = 9
    public let y: Int8
    public let layers: [PalettedStorage]

    public init(y: Int8, layers: [PalettedStorage]) throws {
        guard UInt8(exactly: layers.count) != nil else { throw BedrockError.limitExceeded }
        self.y = y
        self.layers = layers
    }

    public init(decoding bytes: [UInt8]) throws {
        guard bytes.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(bytes[...])
        try self.init(reading: &reader)
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    init(reading reader: inout BedrockReader) throws {
        guard try reader.byte() == Self.version else { throw BedrockError.malformed }
        let count = try reader.byte()
        let y = Int8(bitPattern: try reader.byte())
        let layers = try reader.list(count: UInt32(count), minimumElementSize: 2) {
            let header = try $0.byte()
            return try PalettedStorage(reading: &$0, header: header)
        }
        try self.init(y: y, layers: layers)
    }

    public func encode() throws -> [UInt8] {
        var bytes: [UInt8] = []
        try append(to: &bytes)
        return bytes
    }

    func append(to bytes: inout [UInt8]) throws {
        bytes.append(contentsOf: [Self.version, UInt8(layers.count), UInt8(bitPattern: y)])
        for layer in layers {
            layer.append(to: &bytes)
            guard bytes.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        }
    }
}

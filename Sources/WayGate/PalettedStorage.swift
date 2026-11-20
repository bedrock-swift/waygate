public struct PalettedStorage: Equatable, Sendable {
    public static let valueCount = 4096
    private static let bitWidths = [0, 1, 2, 3, 4, 5, 6, 8, 16]
    public let values: [UInt32] // x then z then y

    public init(values: [UInt32]) throws {
        guard values.count == Self.valueCount else { throw BedrockError.malformed }
        self.values = values
    }

    public init(uniform value: UInt32) {
        values = Array(repeating: value, count: Self.valueCount)
    }

    init(reading reader: inout BedrockReader, header: UInt8) throws {
        let bits = Int(header >> 1)
        guard header & 1 == 1, Self.bitWidths.contains(bits) else { throw BedrockError.malformed }
        if bits == 0 {
            self.init(uniform: UInt32(bitPattern: try reader.varInt()))
            return
        }

        let perWord = 32 / bits
        let count = Self.wordCount(indicesPerWord: perWord)
        let words = try reader.list(count: UInt32(count), minimumElementSize: 4) {
            try $0.littleEndian(UInt32.self)
        }
        let entries = try reader.varInt()
        guard entries > 0, entries <= Self.valueCount, entries <= 1 << bits else { throw BedrockError.malformed }
        let palette = try reader.list(count: UInt32(entries), minimumElementSize: 1) {
            UInt32(bitPattern: try $0.varInt())
        }
        let mask = UInt32((1 << bits) - 1)
        var decoded: [UInt32] = []
        decoded.reserveCapacity(Self.valueCount)
        for index in 0..<Self.valueCount {
            let shift = (index % perWord) * bits
            let slot = Int((words[index / perWord] >> shift) & mask)
            guard slot < palette.count else { throw BedrockError.malformed }
            decoded.append(palette[slot])
        }
        try self.init(values: decoded)
    }

    func append(to bytes: inout [UInt8]) {
        var palette: [UInt32] = []
        var slots: [UInt32: UInt32] = [:]
        var indices: [UInt32] = []
        indices.reserveCapacity(Self.valueCount)
        for value in values {
            if let slot = slots[value] {
                indices.append(slot)
            } else {
                let slot = UInt32(palette.count)
                slots[value] = slot
                palette.append(value)
                indices.append(slot)
            }
        }
        let bits = Self.bitWidths.first { 1 << $0 >= palette.count }!
        bytes.append(UInt8(bits << 1) | 1)
        if bits > 0 {
            let perWord = 32 / bits
            var words = Array(repeating: UInt32(0), count: Self.wordCount(indicesPerWord: perWord))
            for (index, slot) in indices.enumerated() {
                let shift = (index % perWord) * bits
                words[index / perWord] |= slot << shift
            }
            for word in words { bytes.appendLittleEndian(word) }
            bytes.appendVarInt(Int32(palette.count))
        }
        for value in palette { bytes.appendVarInt(Int32(bitPattern: value)) }
    }

    private static func wordCount(indicesPerWord: Int) -> Int {
        (valueCount + indicesPerWord - 1) / indicesPerWord
    }
}

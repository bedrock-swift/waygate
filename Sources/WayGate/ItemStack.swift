public struct ItemStack: Equatable, Sendable {
    public static let empty = ItemStack(networkID: 0, count: 0)
    public let networkID: Int32
    public let count: UInt16
    public let metadata: UInt32
    public let blockRuntimeID: Int32
    public let userData: [UInt8] // little endian nbt and item restrictions

    public init(networkID: Int32, count: UInt16 = 1, metadata: UInt32 = 0, blockRuntimeID: Int32 = 0, userData: [UInt8]? = nil) {
        self.networkID = networkID
        self.count = count
        self.metadata = metadata
        self.blockRuntimeID = blockRuntimeID
        self.userData = userData ?? (networkID == 0 ? [] : [UInt8](repeating: 0, count: 10))
    }

    init(reading reader: inout BedrockReader) throws {
        networkID = try reader.varInt()
        count = try reader.littleEndian(UInt16.self)
        metadata = try reader.varUInt()
        blockRuntimeID = try reader.varInt()
        userData = Array(try reader.varBytes())
    }

    func append(to payload: inout [UInt8]) throws {
        payload.appendVarInt(networkID)
        payload.appendLittleEndian(count)
        payload.appendVarUInt(metadata)
        payload.appendVarInt(blockRuntimeID)
        try payload.appendVarBytes(userData)
    }
}

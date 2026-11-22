public struct ItemInstance: Equatable, Sendable {
    public static let empty = ItemInstance(stack: .empty)
    public let stack: ItemStack
    public let stackNetworkID: Int32?

    public init(stack: ItemStack, stackNetworkID: Int32? = nil) {
        self.stack = stack
        self.stackNetworkID = stackNetworkID
    }

    init(reading reader: inout BedrockReader) throws {
        let networkID = Int32(Int16(bitPattern: try reader.littleEndian(UInt16.self)))
        let count = try reader.littleEndian(UInt16.self)
        let metadata = try reader.varUInt()
        stackNetworkID = try reader.optional { try $0.varInt() }
        let blockRuntimeID = Int32(bitPattern: try reader.varUInt())
        stack = try ItemStack(
            networkID: networkID, count: count, metadata: metadata, blockRuntimeID: blockRuntimeID,
            userData: Array(reader.varBytes())
        )
    }

    func append(to payload: inout [UInt8]) throws {
        guard let networkID = Int16(exactly: stack.networkID) else { throw BedrockError.malformed }
        payload.appendLittleEndian(networkID)
        payload.appendLittleEndian(stack.count)
        payload.appendVarUInt(stack.metadata)
        payload.appendOptional(stackNetworkID) { $0.appendVarInt($1) }
        payload.appendVarUInt(UInt32(bitPattern: stack.blockRuntimeID))
        try payload.appendVarBytes(stack.userData)
    }
}

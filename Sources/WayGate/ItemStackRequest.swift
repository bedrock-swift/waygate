public struct ItemStackRequest: Equatable, Sendable {
    public struct Slot: Equatable, Sendable {
        public let container: FullContainerName
        public let slot: UInt8
        public let stackNetworkID: Int32

        fileprivate init(reading reader: inout BedrockReader) throws {
            container = try FullContainerName(reading: &reader)
            slot = try reader.byte()
            stackNetworkID = try Int32(bitPattern: reader.littleEndian(UInt32.self))
        }
    }

    public struct Ingredient: Equatable, Sendable {
        public enum Descriptor: Equatable, Sendable {
            case empty
            case item(name: String, metadata: Int32)
            case molang(expression: String, version: Int16)
            case tag(String)
        }

        public let descriptor: Descriptor
        public let count: UInt16

        fileprivate init(reading reader: inout BedrockReader) throws {
            let variant = try reader.varUInt()
            _ = try reader.byte() // legacy descriptor id
            switch variant {
            case 0: descriptor = .empty
            case 1: descriptor = try .item(name: reader.string(), metadata: reader.varInt())
            case 2: descriptor = try .molang(
                expression: reader.string(), version: Int16(bitPattern: reader.littleEndian(UInt16.self))
            )
            case 3: descriptor = try .tag(reader.string())
            default: throw BedrockError.malformed
            }
            count = try reader.littleEndian(UInt16.self)
        }
    }

    public struct CraftResult: Equatable, Sendable {
        public let identifier: String?
        public let metadata: Int32
        public let count: Int16
        public let blockRuntimeID: UInt32
        public let userData: [UInt8]

        fileprivate init(reading reader: inout BedrockReader) throws {
            let variant = try reader.varUInt()
            _ = try reader.byte() // legacy descriptor id
            switch variant {
            case 0:
                identifier = nil
                metadata = 0
            case 1:
                identifier = try reader.string()
                metadata = try reader.varInt()
            default:
                throw BedrockError.malformed
            }
            count = try Int16(bitPattern: reader.littleEndian(UInt16.self))
            blockRuntimeID = try reader.varUInt()
            userData = Array(try reader.varBytes())
        }
    }

    public enum Action: Equatable, Sendable {
        case take(count: UInt8, source: Slot, destination: Slot)
        case place(count: UInt8, source: Slot, destination: Slot)
        case swap(source: Slot, destination: Slot)
        case drop(count: UInt8, source: Slot, randomly: Bool)
        case destroy(count: UInt8, source: Slot)
        case consume(count: UInt8, source: Slot)
        case create(resultsSlot: UInt8)
        case labTableCombine
        case beaconPayment(primary: Int32, secondary: Int32)
        case mineBlock(hotbarSlot: Int32, predictedDurability: Int32, stackNetworkID: Int32)
        case craftRecipe(id: UInt32, count: UInt8)
        case autoCraftRecipe(id: UInt32, count: UInt8, ingredients: [Ingredient])
        case craftCreative(id: UInt32, count: UInt8)
        case craftOptionalRecipe(id: UInt32, filterStringIndex: Int32)
        case craftGrindstoneRecipe(id: UInt32, count: UInt8, cost: Int32)
        case craftLoomRecipe(pattern: String, count: UInt8)
        case craftReserved(id: String, count: UInt8)
        case craftNotImplemented
        case craftResults(items: [CraftResult], count: UInt8)

        fileprivate init(reading reader: inout BedrockReader) throws {
            let variant = try reader.varUInt()
            _ = try reader.byte() // legacy action id
            switch variant {
            case 0: self = try .take(count: reader.byte(), source: Slot(reading: &reader), destination: Slot(reading: &reader))
            case 1: self = try .place(count: reader.byte(), source: Slot(reading: &reader), destination: Slot(reading: &reader))
            case 2: self = try .swap(source: Slot(reading: &reader), destination: Slot(reading: &reader))
            case 3: self = try .drop(count: reader.byte(), source: Slot(reading: &reader), randomly: reader.bool())
            case 4: self = try .destroy(count: reader.byte(), source: Slot(reading: &reader))
            case 5: self = try .consume(count: reader.byte(), source: Slot(reading: &reader))
            case 6: self = try .create(resultsSlot: reader.byte())
            case 7: self = .labTableCombine
            case 8: self = try .beaconPayment(primary: reader.varInt(), secondary: reader.varInt())
            case 9:
                self = try .mineBlock(
                    hotbarSlot: reader.varInt(), predictedDurability: reader.varInt(),
                    stackNetworkID: Int32(bitPattern: reader.littleEndian(UInt32.self))
                )
            case 10: self = try .craftRecipe(id: reader.varUInt(), count: reader.byte())
            case 11:
                let id = try reader.varUInt()
                let count = try reader.byte()
                let itemCount = try reader.varUInt()
                let ingredients = try reader.list(count: itemCount, minimumElementSize: 4) { try Ingredient(reading: &$0) }
                self = .autoCraftRecipe(id: id, count: count, ingredients: ingredients)
            case 12: self = try .craftCreative(id: reader.varUInt(), count: reader.byte())
            case 13:
                self = try .craftOptionalRecipe(id: reader.varUInt(), filterStringIndex: Int32(bitPattern: reader.littleEndian(UInt32.self)))
            case 14:
                self = try .craftGrindstoneRecipe(id: reader.littleEndian(UInt32.self), count: reader.byte(), cost: reader.varInt())
            case 15: self = try .craftLoomRecipe(pattern: reader.string(), count: reader.byte())
            case 16: self = try .craftReserved(id: reader.string(), count: reader.byte())
            case 17: self = .craftNotImplemented
            case 18:
                let itemCount = try reader.varUInt()
                let items = try reader.list(count: itemCount, minimumElementSize: 6) { try CraftResult(reading: &$0) }
                self = try .craftResults(items: items, count: reader.byte())
            default: throw BedrockError.malformed
            }
        }
    }

    public struct Entry: Equatable, Sendable {
        public let requestID: Int32
        public let actions: [Action]
        public let filterStrings: [String]
        public let filterCause: Int32

        init(reading reader: inout BedrockReader) throws {
            requestID = try reader.varInt()
            let actionCount = try reader.varUInt()
            actions = try reader.list(count: actionCount, minimumElementSize: 2) { try Action(reading: &$0) }
            let filterCount = try reader.varUInt()
            filterStrings = try reader.list(count: filterCount, minimumElementSize: 1) { try $0.string() }
            filterCause = try Int32(bitPattern: reader.littleEndian(UInt32.self))
        }
    }

    public static let packetID: UInt16 = 147
    public let entries: [Entry]

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let count = try reader.varUInt()
        entries = try reader.list(count: count, minimumElementSize: 7) { try Entry(reading: &$0) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }
}

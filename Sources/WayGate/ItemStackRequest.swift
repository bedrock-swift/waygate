public struct ItemStackRequest: Equatable, Sendable {
    public struct Slot: Equatable, Sendable {
        public let container: FullContainerName
        public let slot: UInt8
        public let stackNetworkID: Int32

        public init(container: FullContainerName, slot: UInt8, stackNetworkID: Int32) {
            self.container = container
            self.slot = slot
            self.stackNetworkID = stackNetworkID
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            container = try FullContainerName(reading: &reader)
            slot = try reader.byte()
            stackNetworkID = try Int32(bitPattern: reader.littleEndian(UInt32.self))
        }

        fileprivate func append(to payload: inout [UInt8]) {
            container.append(to: &payload)
            payload.append(slot)
            payload.appendLittleEndian(stackNetworkID)
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

        public init(descriptor: Descriptor, count: UInt16) {
            self.descriptor = descriptor
            self.count = count
        }

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

        fileprivate func append(to payload: inout [UInt8]) throws {
            switch descriptor {
            case .empty: payload += [0, 0]
            case let .item(name, metadata):
                payload += [1, 1]
                try payload.appendString(name)
                payload.appendVarInt(metadata)
            case let .molang(expression, version):
                payload += [2, 2]
                try payload.appendString(expression)
                payload.appendLittleEndian(version)
            case let .tag(name):
                payload += [3, 3]
                try payload.appendString(name)
            }
            payload.appendLittleEndian(count)
        }
    }

    public struct CraftResult: Equatable, Sendable {
        public let identifier: String?
        public let metadata: Int32
        public let count: Int16
        public let blockRuntimeID: UInt32
        public let userData: [UInt8]

        public init(identifier: String? = nil, metadata: Int32 = 0, count: Int16, blockRuntimeID: UInt32, userData: [UInt8] = []) {
            self.identifier = identifier
            self.metadata = metadata
            self.count = count
            self.blockRuntimeID = blockRuntimeID
            self.userData = userData
        }

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

        fileprivate func append(to payload: inout [UInt8]) throws {
            if let identifier {
                payload += [1, 1]
                try payload.appendString(identifier)
                payload.appendVarInt(metadata)
            } else {
                guard metadata == 0 else { throw BedrockError.malformed }
                payload += [0, 0]
            }
            payload.appendLittleEndian(count)
            payload.appendVarUInt(blockRuntimeID)
            try payload.appendVarBytes(userData)
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

        fileprivate func append(to payload: inout [UInt8]) throws {
            switch self {
            case let .take(count, source, destination):
                payload += [0, 0, count]
                source.append(to: &payload)
                destination.append(to: &payload)
            case let .place(count, source, destination):
                payload += [1, 1, count]
                source.append(to: &payload)
                destination.append(to: &payload)
            case let .swap(source, destination):
                payload += [2, 2]
                source.append(to: &payload)
                destination.append(to: &payload)
            case let .drop(count, source, randomly):
                payload += [3, 3, count]
                source.append(to: &payload)
                payload.append(randomly ? 1 : 0)
            case let .destroy(count, source):
                payload += [4, 4, count]
                source.append(to: &payload)
            case let .consume(count, source):
                payload += [5, 5, count]
                source.append(to: &payload)
            case let .create(slot): payload += [6, 6, slot]
            case .labTableCombine: payload += [7, 9]
            case let .beaconPayment(primary, secondary):
                payload += [8, 10]
                payload.appendVarInt(primary)
                payload.appendVarInt(secondary)
            case let .mineBlock(slot, durability, stackNetworkID):
                payload += [9, 11]
                payload.appendVarInt(slot)
                payload.appendVarInt(durability)
                payload.appendLittleEndian(stackNetworkID)
            case let .craftRecipe(id, count):
                payload += [10, 12]
                payload.appendVarUInt(id)
                payload.append(count)
            case let .autoCraftRecipe(id, count, ingredients):
                guard let length = UInt32(exactly: ingredients.count) else { throw BedrockError.limitExceeded }
                payload += [11, 13]
                payload.appendVarUInt(id)
                payload.append(count)
                payload.appendVarUInt(length)
                for ingredient in ingredients { try ingredient.append(to: &payload) }
            case let .craftCreative(id, count):
                payload += [12, 14]
                payload.appendVarUInt(id)
                payload.append(count)
            case let .craftOptionalRecipe(id, filterStringIndex):
                payload += [13, 15]
                payload.appendVarUInt(id)
                payload.appendLittleEndian(filterStringIndex)
            case let .craftGrindstoneRecipe(id, count, cost):
                payload += [14, 16]
                payload.appendLittleEndian(id)
                payload.append(count)
                payload.appendVarInt(cost)
            case let .craftLoomRecipe(pattern, count):
                payload += [15, 17]
                try payload.appendString(pattern)
                payload.append(count)
            case let .craftReserved(id, count):
                payload += [16, 18]
                try payload.appendString(id)
                payload.append(count)
            case .craftNotImplemented: payload += [17, 19]
            case let .craftResults(items, count):
                guard let length = UInt32(exactly: items.count) else { throw BedrockError.limitExceeded }
                payload += [18, 20]
                payload.appendVarUInt(length)
                for item in items { try item.append(to: &payload) }
                payload.append(count)
            }
        }
    }

    public struct Entry: Equatable, Sendable {
        public let requestID: Int32
        public let actions: [Action]
        public let filterStrings: [String]
        public let filterCause: Int32

        public init(requestID: Int32, actions: [Action], filterStrings: [String] = [], filterCause: Int32 = 0) {
            self.requestID = requestID
            self.actions = actions
            self.filterStrings = filterStrings
            self.filterCause = filterCause
        }

        init(reading reader: inout BedrockReader) throws {
            requestID = try reader.varInt()
            let actionCount = try reader.varUInt()
            actions = try reader.list(count: actionCount, minimumElementSize: 2) { try Action(reading: &$0) }
            let filterCount = try reader.varUInt()
            filterStrings = try reader.list(count: filterCount, minimumElementSize: 1) { try $0.string() }
            filterCause = try Int32(bitPattern: reader.littleEndian(UInt32.self))
        }

        fileprivate func append(to payload: inout [UInt8]) throws {
            guard let actionCount = UInt32(exactly: actions.count), let filterCount = UInt32(exactly: filterStrings.count) else {
                throw BedrockError.limitExceeded
            }
            payload.appendVarInt(requestID)
            payload.appendVarUInt(actionCount)
            for action in actions {
                try action.append(to: &payload)
                guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
            }
            payload.appendVarUInt(filterCount)
            for filter in filterStrings { try payload.appendString(filter) }
            payload.appendLittleEndian(filterCause)
        }
    }

    public static let packetID: UInt16 = 147
    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let count = try reader.varUInt()
        entries = try reader.list(count: count, minimumElementSize: 7) { try Entry(reading: &$0) }
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let count = UInt32(exactly: entries.count) else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        payload.appendVarUInt(count)
        for entry in entries {
            try entry.append(to: &payload)
            guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

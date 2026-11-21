public struct VoxelShapes: Equatable, Sendable {
    public struct Shape: Equatable, Sendable {
        public let size: SIMD3<UInt8>
        public let cells: [UInt8]
        public let xCoordinates: [Float]
        public let yCoordinates: [Float]
        public let zCoordinates: [Float]

        public init(size: SIMD3<UInt8>, cells: [UInt8], xCoordinates: [Float], yCoordinates: [Float], zCoordinates: [Float]) {
            self.size = size
            self.cells = cells
            self.xCoordinates = xCoordinates
            self.yCoordinates = yCoordinates
            self.zCoordinates = zCoordinates
        }

        fileprivate init(reading reader: inout BedrockReader) throws {
            size = try SIMD3(reader.byte(), reader.byte(), reader.byte())
            cells = Array(try reader.varBytes())
            xCoordinates = try Self.readCoordinates(from: &reader)
            yCoordinates = try Self.readCoordinates(from: &reader)
            zCoordinates = try Self.readCoordinates(from: &reader)
        }

        fileprivate func append(to bytes: inout [UInt8]) throws {
            bytes.append(contentsOf: [size.x, size.y, size.z])
            try bytes.appendVarBytes(cells)
            for axis in [xCoordinates, yCoordinates, zCoordinates] {
                guard let count = UInt32(exactly: axis.count),
                      axis.count <= (BedrockBatch.maximumBytes - bytes.count - 5) / 4 else {
                    throw BedrockError.limitExceeded
                }
                bytes.appendVarUInt(count)
                for coordinate in axis { bytes.appendLittleEndian(coordinate.bitPattern) }
            }
        }

        private static func readCoordinates(from reader: inout BedrockReader) throws -> [Float] {
            let count = try reader.varUInt()
            return try reader.list(count: count, minimumElementSize: 4) {
                Float(bitPattern: try $0.littleEndian(UInt32.self))
            }
        }
    }

    public struct NameEntry: Equatable, Sendable {
        public let name: String
        public let id: UInt16

        public init(name: String, id: UInt16) {
            self.name = name
            self.id = id
        }
    }

    public static let packetID: UInt16 = 237
    public let shapes: [Shape]
    public let names: [NameEntry]
    public let customShapeCount: UInt16

    public init(shapes: [Shape] = [], names: [NameEntry] = [], customShapeCount: UInt16 = 0) {
        self.shapes = shapes
        self.names = names
        self.customShapeCount = customShapeCount
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        let shapeCount = try reader.varUInt()
        shapes = try reader.list(count: shapeCount, minimumElementSize: 7) { try Shape(reading: &$0) }
        let nameCount = try reader.varUInt()
        names = try reader.list(count: nameCount, minimumElementSize: 3) {
            try NameEntry(name: $0.string(), id: $0.littleEndian(UInt16.self))
        }
        customShapeCount = try reader.littleEndian(UInt16.self)
        guard reader.isEmpty else { throw BedrockError.malformed }
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let shapeCount = UInt32(exactly: shapes.count), let nameCount = UInt32(exactly: names.count) else {
            throw BedrockError.limitExceeded
        }
        var payload: [UInt8] = []
        payload.appendVarUInt(shapeCount)
        for shape in shapes { try shape.append(to: &payload) }
        payload.appendVarUInt(nameCount)
        for entry in names {
            try payload.appendString(entry.name)
            payload.appendLittleEndian(entry.id)
        }
        payload.appendLittleEndian(customShapeCount)
        guard payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

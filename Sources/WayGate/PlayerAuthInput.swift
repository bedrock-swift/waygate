public struct PlayerAuthInput: Equatable, Sendable {
    public static let packetID: UInt16 = 144
    private static let flagCount: UInt32 = 66
    private static let trailingVectorBytes = 28 // analogue move, camera and raw move

    public let rotation: SIMD2<Float>
    public let position: SIMD3<Float>
    public let move: SIMD2<Float>
    public let headYaw: Float
    public let flags: [Int32]
    public let inputMode: UInt32
    public let playMode: UInt32
    public let interactionModel: Int32
    public let interactionRotation: SIMD2<Float>
    public let tick: UInt64
    public let delta: SIMD3<Float>
    public let optionalData: [UInt8] // interaction, inventory, block actions and vehicle fields
    public let analogueMove: SIMD2<Float>
    public let cameraOrientation: SIMD3<Float>
    public let rawMove: SIMD2<Float>

    public init(
        rotation: SIMD2<Float>, position: SIMD3<Float>, move: SIMD2<Float>, headYaw: Float, flags: [Int32],
        inputMode: UInt32, playMode: UInt32, interactionModel: Int32, interactionRotation: SIMD2<Float>,
        tick: UInt64, delta: SIMD3<Float>, optionalData: [UInt8] = [0, 0, 0, 0, 0],
        analogueMove: SIMD2<Float>, cameraOrientation: SIMD3<Float>, rawMove: SIMD2<Float>
    ) {
        self.rotation = rotation
        self.position = position
        self.move = move
        self.headYaw = headYaw
        self.flags = flags
        self.inputMode = inputMode
        self.playMode = playMode
        self.interactionModel = interactionModel
        self.interactionRotation = interactionRotation
        self.tick = tick
        self.delta = delta
        self.optionalData = optionalData
        self.analogueMove = analogueMove
        self.cameraOrientation = cameraOrientation
        self.rawMove = rawMove
    }

    public init(decoding packet: BedrockPacket) throws {
        guard packet.id == Self.packetID else { throw BedrockError.unexpectedPacket(packet.id) }
        guard packet.payload.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var reader = BedrockReader(packet.payload[...])
        rotation = try SIMD2(reader.float32(), reader.float32())
        position = try SIMD3(reader.float32(), reader.float32(), reader.float32())
        move = try SIMD2(reader.float32(), reader.float32())
        headYaw = try reader.float32()
        let count = try reader.varUInt()
        guard count <= Self.flagCount else { throw BedrockError.malformed }
        flags = try reader.list(count: count, minimumElementSize: 1) { try $0.varInt() }
        try Self.validate(flags: flags)
        inputMode = try reader.varUInt()
        playMode = try reader.varUInt()
        interactionModel = try reader.varInt()
        interactionRotation = try SIMD2(reader.float32(), reader.float32())
        tick = try reader.varULong()
        delta = try SIMD3(reader.float32(), reader.float32(), reader.float32())
        let optionalSize = reader.remaining - Self.trailingVectorBytes
        guard optionalSize >= 5 else { throw BedrockError.malformed }
        optionalData = Array(try reader.read(optionalSize))
        analogueMove = try SIMD2(reader.float32(), reader.float32())
        cameraOrientation = try SIMD3(reader.float32(), reader.float32(), reader.float32())
        rawMove = try SIMD2(reader.float32(), reader.float32())
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        try Self.validate(flags: flags)
        guard optionalData.count >= 5 else { throw BedrockError.malformed }
        guard optionalData.count <= BedrockBatch.maximumBytes else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        for value in [rotation.x, rotation.y, position.x, position.y, position.z, move.x, move.y, headYaw] {
            payload.appendLittleEndian(value.bitPattern)
        }
        payload.appendVarUInt(UInt32(flags.count))
        for flag in flags { payload.appendVarInt(flag) }
        payload.appendVarUInt(inputMode)
        payload.appendVarUInt(playMode)
        payload.appendVarInt(interactionModel)
        payload.appendLittleEndian(interactionRotation.x.bitPattern)
        payload.appendLittleEndian(interactionRotation.y.bitPattern)
        payload.appendVarULong(tick)
        for value in [delta.x, delta.y, delta.z] { payload.appendLittleEndian(value.bitPattern) }
        guard optionalData.count <= BedrockBatch.maximumBytes - payload.count - Self.trailingVectorBytes else {
            throw BedrockError.limitExceeded
        }
        payload += optionalData
        for value in [analogueMove.x, analogueMove.y, cameraOrientation.x, cameraOrientation.y, cameraOrientation.z,
                      rawMove.x, rawMove.y] {
            payload.appendLittleEndian(value.bitPattern)
        }
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }

    public struct BlockAction: Equatable, Sendable {
        public let action: Int32
        public let position: SIMD3<Int32>
        public let face: Int32
    }

    public struct MovementActions: Equatable, Sendable {
        public let blocks: [BlockAction]?
        public let vehicleRotation: SIMD2<Float>?
        public let predictedVehicleID: Int64?
    }

    public func movementActions() throws -> MovementActions? {
        var reader = BedrockReader(optionalData[...])
        _ = try reader.optional { try ItemInteraction(reading: &$0) }
        _ = try reader.optional { try ItemStackRequest.Entry(reading: &$0) }
        let blocks = try reader.optional { reader in
            let count = try reader.varUInt()
            guard count <= 100 else { throw BedrockError.limitExceeded }
            return try reader.list(count: count, minimumElementSize: 5) {
                try BlockAction(action: $0.varInt(), position: $0.blockPosition(), face: $0.varInt())
            }
        }
        let vehicleRotation = try reader.optional { try SIMD2($0.float32(), $0.float32()) }
        let predictedVehicleID = try reader.optional {
            let encoded = try $0.varULong()
            return Int64(bitPattern: (encoded >> 1) ^ (0 &- (encoded & 1)))
        }
        guard reader.isEmpty else { throw BedrockError.malformed }
        return MovementActions(blocks: blocks, vehicleRotation: vehicleRotation, predictedVehicleID: predictedVehicleID)
    }

    public func itemStackRequest() throws -> ItemStackRequest.Entry? {
        var reader = BedrockReader(optionalData[...])
        _ = try reader.optional { try ItemInteraction(reading: &$0) }
        return try reader.optional { try ItemStackRequest.Entry(reading: &$0) }
    }

    private static func validate(flags: [Int32]) throws {
        guard flags.count <= Int(flagCount), flags.allSatisfy({ $0 >= 0 && UInt32($0) < flagCount }),
              Set(flags).count == flags.count else { throw BedrockError.malformed }
    }
}

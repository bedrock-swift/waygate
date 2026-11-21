import Foundation

public struct StartGame: Equatable, Sendable {
    public struct Player: Equatable, Sendable {
        public var uniqueID: Int64
        public var runtimeID: UInt64
        public var gameMode: Int32
        public var position: SIMD3<Float>
        public var pitch: Float
        public var yaw: Float

        public init(
            uniqueID: Int64, runtimeID: UInt64, gameMode: Int32 = 0, position: SIMD3<Float> = .zero,
            pitch: Float = 0, yaw: Float = 0
        ) {
            self.uniqueID = uniqueID
            self.runtimeID = runtimeID
            self.gameMode = gameMode
            self.position = position
            self.pitch = pitch
            self.yaw = yaw
        }
    }

    public struct World: Equatable, Sendable {
        public var seed: Int64 = 0
        public var spawnBiomeType: Int16 = 0
        public var biomeName: String = ""
        public var dimension: Int32 = 0
        public var generator: Int32 = 0
        public var gameMode: Int32 = 0
        public var hardcore: Bool = false
        public var difficulty: Int32 = 0
        public var spawn: SIMD3<Int32> = .zero
        public var achievementsDisabled: Bool = false
        public var editorWorldType: Int32 = 0
        public var createdInEditor: Bool = false
        public var exportedFromEditor: Bool = false
        public var editorLevelMigrationVersion: Int8 = 0
        public var dayCycleLockTime: Int32 = 0
        public var educationEditionOffer: UInt32 = 0
        public var educationFeaturesEnabled: Bool = false
        public var educationProductID: String = ""
        public var rainLevel: Float = 0
        public var lightningLevel: Float = 0
        public var confirmedPlatformLockedContent: Bool = false
        public var multiplayerGame: Bool = false
        public var lanBroadcastEnabled: Bool = false
        public var xboxBroadcastMode: Int32 = 0
        public var platformBroadcastMode: Int32 = 0
        public var commandsEnabled: Bool = false
        public var texturePackRequired: Bool = false
        public var gameRules: [GameRule] = []
        public var experiments: [ResourcePackStack.Experiment] = []
        public var experimentsPreviouslyToggled: Bool = false
        public var bonusChestEnabled: Bool = false
        public var startWithMapEnabled: Bool = false
        public var playerPermissions: UInt8 = 0
        public var serverChunkTickRadius: Int32 = 0
        public var hasLockedBehaviourPack: Bool = false
        public var hasLockedTexturePack: Bool = false
        public var fromLockedWorldTemplate: Bool = false
        public var msaGamerTagsOnly: Bool = false
        public var fromWorldTemplate: Bool = false
        public var worldTemplateSettingsLocked: Bool = false
        public var onlySpawnV1Villagers: Bool = false
        public var personaDisabled: Bool = false
        public var customSkinsDisabled: Bool = false
        public var emoteChatMuted: Bool = false
        public var baseGameVersion: String = ""
        public var limitedWorldWidth: Int32 = 0
        public var limitedWorldDepth: Int32 = 0
        public var newNether: Bool = false
        public var educationResourceButtonName: String = ""
        public var educationResourceLink: String = ""
        public var forceExperimentalGameplay: Bool? = nil
        public var chatRestrictionLevel: UInt8 = 0
        public var disablePlayerInteractions: Bool = false
        public var serverEditorConnectionPolicy: Int32 = 0
        public var allowAnonymousBlockDropsInEditorWorlds: Bool = false
        public var levelID: String = ""
        public var name: String = ""
        public var templateContentIdentity: String = ""
        public var trial: Bool = false

        public init(name: String, baseGameVersion: String = "1.26.60") {
            self.name = name
            self.baseGameVersion = baseGameVersion
        }
    }

    public struct Block: Equatable, Sendable {
        public let name: String
        public let properties: NetworkNBT

        public init(name: String, properties: NetworkNBT) {
            self.name = name
            self.properties = properties
        }
    }

    public static let packetID: UInt16 = 11
    public var player: Player
    public var world: World
    public var gameVersion: String
    public var rewindHistorySize: Int32 = 0
    public var serverAuthoritativeBlockBreaking = false
    public var time: Int64 = 0
    public var enchantmentSeed: Int32 = 0
    public var blocks: [Block] = []
    public var multiplayerCorrelationID = ""
    public var serverAuthoritativeInventory = false
    public var propertyData: NetworkNBT = .empty
    public var serverBlockStateChecksum: UInt64 = 0
    public var worldTemplateID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    public var clientSideGeneration = false
    public var useBlockNetworkIDHashes = false
    public var serverAuthoritativeSound = false
    public var serverID = ""
    public var scenarioID = ""
    public var worldID = ""
    public var ownerID = ""

    public init(player: Player, world: World, gameVersion: String = "1.26.60") {
        self.player = player
        self.world = world
        self.gameVersion = gameVersion
    }

    public func packet(sender: UInt8 = 0, target: UInt8 = 0) throws -> BedrockPacket {
        guard let rules = UInt32(exactly: world.gameRules.count), let experiments = UInt32(exactly: world.experiments.count),
              let blocks = UInt32(exactly: blocks.count) else { throw BedrockError.limitExceeded }
        var payload: [UInt8] = []
        let uniqueID = (UInt64(bitPattern: player.uniqueID) << 1) ^ UInt64(bitPattern: player.uniqueID >> 63)
        payload.appendActorID(uniqueID)
        payload.appendActorID(player.runtimeID)
        payload.appendVarInt(player.gameMode)
        payload.appendLittleEndian(player.position.x.bitPattern)
        payload.appendLittleEndian(player.position.y.bitPattern)
        payload.appendLittleEndian(player.position.z.bitPattern)
        payload.appendLittleEndian(player.pitch.bitPattern)
        payload.appendLittleEndian(player.yaw.bitPattern)
        payload.appendLittleEndian(world.seed)
        payload.appendLittleEndian(world.spawnBiomeType)
        try payload.appendString(world.biomeName)
        payload.appendVarInt(world.dimension)
        payload.appendVarInt(world.generator)
        payload.appendVarInt(world.gameMode)
        payload.append(world.hardcore ? 1 : 0)
        payload.appendVarInt(world.difficulty)
        payload.appendBlockPosition(world.spawn)
        payload.append(world.achievementsDisabled ? 1 : 0)
        payload.appendVarInt(world.editorWorldType)
        payload.append(world.createdInEditor ? 1 : 0)
        payload.append(world.exportedFromEditor ? 1 : 0)
        payload.append(UInt8(bitPattern: world.editorLevelMigrationVersion))
        payload.appendVarInt(world.dayCycleLockTime)
        payload.appendVarUInt(world.educationEditionOffer)
        payload.append(world.educationFeaturesEnabled ? 1 : 0)
        try payload.appendString(world.educationProductID)
        payload.appendLittleEndian(world.rainLevel.bitPattern)
        payload.appendLittleEndian(world.lightningLevel.bitPattern)
        payload.append(world.confirmedPlatformLockedContent ? 1 : 0)
        payload.append(world.multiplayerGame ? 1 : 0)
        payload.append(world.lanBroadcastEnabled ? 1 : 0)
        payload.appendVarInt(world.xboxBroadcastMode)
        payload.appendVarInt(world.platformBroadcastMode)
        payload.append(world.commandsEnabled ? 1 : 0)
        payload.append(world.texturePackRequired ? 1 : 0)
        payload.appendVarUInt(rules)
        for rule in world.gameRules { try rule.append(to: &payload) }
        payload.appendLittleEndian(experiments)
        for experiment in world.experiments {
            try payload.appendString(experiment.name)
            payload.append(experiment.enabled ? 1 : 0)
        }
        payload.append(world.experimentsPreviouslyToggled ? 1 : 0)
        payload.append(world.bonusChestEnabled ? 1 : 0)
        payload.append(world.startWithMapEnabled ? 1 : 0)
        payload.append(world.playerPermissions)
        payload.appendLittleEndian(world.serverChunkTickRadius)
        payload.append(world.hasLockedBehaviourPack ? 1 : 0)
        payload.append(world.hasLockedTexturePack ? 1 : 0)
        payload.append(world.fromLockedWorldTemplate ? 1 : 0)
        payload.append(world.msaGamerTagsOnly ? 1 : 0)
        payload.append(world.fromWorldTemplate ? 1 : 0)
        payload.append(world.worldTemplateSettingsLocked ? 1 : 0)
        payload.append(world.onlySpawnV1Villagers ? 1 : 0)
        payload.append(world.personaDisabled ? 1 : 0)
        payload.append(world.customSkinsDisabled ? 1 : 0)
        payload.append(world.emoteChatMuted ? 1 : 0)
        try payload.appendString(world.baseGameVersion)
        payload.appendLittleEndian(world.limitedWorldWidth)
        payload.appendLittleEndian(world.limitedWorldDepth)
        payload.append(world.newNether ? 1 : 0)
        try payload.appendString(world.educationResourceButtonName)
        try payload.appendString(world.educationResourceLink)
        payload.append(world.forceExperimentalGameplay == nil ? 0 : 1)
        if let value = world.forceExperimentalGameplay { payload.append(value ? 1 : 0) }
        payload.append(world.chatRestrictionLevel)
        payload.append(world.disablePlayerInteractions ? 1 : 0)
        payload.appendVarInt(world.serverEditorConnectionPolicy)
        payload.append(world.allowAnonymousBlockDropsInEditorWorlds ? 1 : 0)
        try payload.appendString(world.levelID)
        try payload.appendString(world.name)
        try payload.appendString(world.templateContentIdentity)
        payload.append(world.trial ? 1 : 0)
        payload.appendVarInt(rewindHistorySize)
        payload.append(serverAuthoritativeBlockBreaking ? 1 : 0)
        payload.appendLittleEndian(time)
        payload.appendVarInt(enchantmentSeed)
        payload.appendVarUInt(blocks)
        for block in self.blocks {
            try payload.appendString(block.name)
            try payload.appendCompound(block.properties)
        }
        try payload.appendString(multiplayerCorrelationID)
        payload.append(serverAuthoritativeInventory ? 1 : 0)
        try payload.appendString(gameVersion)
        try payload.appendCompound(propertyData)
        payload.appendLittleEndian(serverBlockStateChecksum)
        payload.appendUUID(worldTemplateID)
        payload.append(clientSideGeneration ? 1 : 0)
        payload.append(useBlockNetworkIDHashes ? 1 : 0)
        payload.append(serverAuthoritativeSound ? 1 : 0)
        payload.append(0) // no server join information
        try payload.appendString(serverID)
        try payload.appendString(scenarioID)
        try payload.appendString(worldID)
        try payload.appendString(ownerID)
        return try BedrockPacket(id: Self.packetID, sender: sender, target: target, payload: payload)
    }
}

private extension [UInt8] {
    mutating func appendActorID(_ value: UInt64) {
        var remaining = value
        while remaining >= 128 {
            append(UInt8(remaining & 127) | 128)
            remaining >>= 7
        }
        append(UInt8(remaining))
    }

    mutating func appendCompound(_ compound: NetworkNBT) throws {
        guard compound.bytes.count <= BedrockBatch.maximumBytes - count else { throw BedrockError.limitExceeded }
        append(contentsOf: compound.bytes)
    }
}

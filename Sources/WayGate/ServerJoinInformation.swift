import Foundation

public struct ServerJoinInformation: Equatable, Sendable {
    public struct Gathering: Equatable, Sendable {
        public var experienceID: UUID
        public var experienceName: String
        public var experienceWorldID: UUID?
        public var experienceWorldName: String?
        public var creatorID: String
        public var targetID: UUID?
        public var scenarioID: String?
        public var serverID: String?

        public init(experienceID: UUID, experienceName: String, creatorID: String) {
            self.experienceID = experienceID
            self.experienceName = experienceName
            self.creatorID = creatorID
        }

        init(reading reader: inout BedrockReader) throws {
            experienceID = try reader.uuid()
            experienceName = try reader.string()
            experienceWorldID = try reader.optional { try $0.uuid() }
            experienceWorldName = try reader.optional { try $0.string() }
            creatorID = try reader.string()
            targetID = try reader.optional { try $0.uuid() }
            scenarioID = try reader.optional { try $0.string() }
            serverID = try reader.optional { try $0.string() }
        }

        func append(to bytes: inout [UInt8]) throws {
            bytes.appendUUID(experienceID)
            try bytes.appendString(experienceName)
            bytes.appendOptional(experienceWorldID) { $0.appendUUID($1) }
            try bytes.appendOptional(experienceWorldName) { try $0.appendString($1) }
            try bytes.appendString(creatorID)
            bytes.appendOptional(targetID) { $0.appendUUID($1) }
            try bytes.appendOptional(scenarioID) { try $0.appendString($1) }
            try bytes.appendOptional(serverID) { try $0.appendString($1) }
        }
    }

    public struct Store: Equatable, Sendable {
        public var id: String
        public var name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public struct Presence: Equatable, Sendable {
        public var richPresenceID: String?

        public init(richPresenceID: String? = nil) {
            self.richPresenceID = richPresenceID
        }
    }

    public var gathering: Gathering?
    public var store: Store?
    public var presence: Presence?

    public init(gathering: Gathering? = nil, store: Store? = nil, presence: Presence? = nil) {
        self.gathering = gathering
        self.store = store
        self.presence = presence
    }

    init(reading reader: inout BedrockReader) throws {
        gathering = try reader.optional { try Gathering(reading: &$0) }
        store = try reader.optional { try Store(id: $0.string(), name: $0.string()) }
        presence = try reader.optional { try Presence(richPresenceID: $0.optional { try $0.string() }) }
    }

    func append(to bytes: inout [UInt8]) throws {
        try bytes.appendOptional(gathering) { try $1.append(to: &$0) }
        try bytes.appendOptional(store) { bytes, store in
            try bytes.appendString(store.id)
            try bytes.appendString(store.name)
        }
        try bytes.appendOptional(presence) { bytes, presence in
            try bytes.appendOptional(presence.richPresenceID) { try $0.appendString($1) }
        }
    }
}

extension BedrockReader {
    mutating func optional<T>(_ read: (inout Self) throws -> T) throws -> T? {
        try bool() ? try read(&self) : nil
    }
}

extension [UInt8] {
    mutating func appendOptional<T>(_ value: T?, _ append: (inout Self, T) throws -> Void) rethrows {
        self.append(value == nil ? 0 : 1)
        if let value { try append(&self, value) }
    }
}

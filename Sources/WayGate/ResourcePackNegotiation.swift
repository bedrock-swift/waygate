public enum ResourcePackNegotiationError: Error, Equatable {
    case invalidOffer
    case unexpectedResponse
    case refused
}

public struct ResourcePackNegotiation: Sendable {
    private struct OfferedPack: Sendable {
        let version: String
        let archive: ResourcePackArchive?
    }

    private struct Download: Sendable {
        let identifier: String
        let archive: ResourcePackArchive
        let version: String

        func information() -> ResourcePackDataInfo {
            let info = archive.dataInfo
            return ResourcePackDataInfo(
                packID: identifier, chunkSize: info.chunkSize, chunkCount: info.chunkCount, size: info.size,
                hash: info.hash, premium: info.premium, packType: info.packType
            )
        }
    }

    private enum State: Sendable {
        case idle
        case offered
        case sending(ArraySlice<Download>, index: UInt32)
        case awaitingDownloaded
        case awaitingCompletion
        case refused
        case complete
    }

    private let offer: BedrockPacket
    private let stack: BedrockPacket
    private let packs: [String: OfferedPack]
    private let format: ResourcePackFormat
    private var state: State = .idle
    public private(set) var clientCacheEnabled: Bool?

    public var isComplete: Bool {
        if case .complete = state { return true }
        return false
    }

    public init(
        info: ResourcePacksInfo, stack: ResourcePackStack, archives: [ResourcePackArchive] = [],
        format: ResourcePackFormat = .v26_60
    ) throws {
        var archivesByID: [String: ResourcePackArchive] = [:]
        for archive in archives {
            guard archivesByID.updateValue(archive, forKey: archive.dataInfo.packID) == nil else {
                throw ResourcePackNegotiationError.invalidOffer
            }
        }
        var packs: [String: OfferedPack] = [:]
        for pack in info.texturePacks {
            let id = pack.id.uuidString.lowercased()
            let archive = archivesByID.removeValue(forKey: id)
            guard packs[id] == nil, archive == nil || archive?.dataInfo.size == pack.size else {
                throw ResourcePackNegotiationError.invalidOffer
            }
            packs[id] = OfferedPack(version: pack.version, archive: archive)
        }
        guard archivesByID.isEmpty else { throw ResourcePackNegotiationError.invalidOffer }
        offer = try info.packet(format: format)
        self.stack = try stack.packet(format: format)
        self.packs = packs
        self.format = format
    }

    public mutating func begin() throws -> BedrockPacket {
        guard case .idle = state else { throw ResourcePackNegotiationError.unexpectedResponse }
        state = .offered
        return offer
    }

    public mutating func receive(_ packet: BedrockPacket) throws -> [BedrockPacket] {
        guard packet.sender == 0, packet.target == 0 else { throw BedrockError.malformed }
        switch packet.id {
        case ClientCacheStatus.packetID:
            switch state {
            case .offered, .sending, .awaitingDownloaded, .awaitingCompletion:
                guard clientCacheEnabled == nil else { throw ResourcePackNegotiationError.unexpectedResponse }
                clientCacheEnabled = try ClientCacheStatus(decoding: packet).enabled
                return []
            default:
                throw ResourcePackNegotiationError.unexpectedResponse
            }
        case ResourcePackClientResponse.packetID:
            return try respond(to: ResourcePackClientResponse(decoding: packet, format: format))
        case ResourcePackChunkRequest.packetID:
            return try sendChunk(for: ResourcePackChunkRequest(decoding: packet, format: format))
        default:
            throw BedrockError.unexpectedPacket(packet.id)
        }
    }

    private mutating func respond(to response: ResourcePackClientResponse) throws -> [BedrockPacket] {
        switch (state, response.status) {
        case (.offered, .refused), (.sending, .refused), (.awaitingDownloaded, .refused), (.awaitingCompletion, .refused):
            state = .refused
            throw ResourcePackNegotiationError.refused
        case (.offered, .sendPacks):
            var downloads: [Download] = []
            var requested: Set<String> = []
            for identifier in response.packIDs {
                let parts = identifier.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: false)
                guard let id = parts.first?.lowercased(), let pack = packs[id], let archive = pack.archive,
                      parts.count == 1 || parts[1] == pack.version else { throw ResourcePackTransferError.unexpectedPack }
                if requested.insert(id).inserted {
                    downloads.append(Download(identifier: identifier, archive: archive, version: pack.version))
                }
            }
            guard let first = downloads.first else {
                state = .awaitingDownloaded
                return []
            }
            let information = try first.information().packet()
            state = .sending(downloads[...], index: 0)
            return [information]
        case (.offered, .allPacksDownloaded), (.awaitingDownloaded, .allPacksDownloaded):
            state = .awaitingCompletion
            return [stack]
        case (.awaitingCompletion, .completed):
            state = .complete
            return []
        default:
            throw ResourcePackNegotiationError.unexpectedResponse
        }
    }

    private mutating func sendChunk(for request: ResourcePackChunkRequest) throws -> [BedrockPacket] {
        guard case let .sending(downloads, index) = state, let current = downloads.first else {
            throw ResourcePackNegotiationError.unexpectedResponse
        }
        let id = current.archive.dataInfo.packID
        let parts = request.packID.split(separator: "_", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.first?.lowercased() == id, parts.count == 1 || parts[1] == current.version else {
            throw ResourcePackTransferError.unexpectedPack
        }
        guard request.index == index else { throw ResourcePackTransferError.invalidChunkIndex }
        let stored = try current.archive.chunk(for: .init(packID: id, index: index))
        let response = try ResourcePackChunkData(
            packID: request.packID, index: stored.index, offset: stored.offset, data: stored.data
        ).packet()
        let nextIndex = index + 1
        if nextIndex < current.archive.dataInfo.chunkCount {
            state = .sending(downloads, index: nextIndex)
            return [response]
        }
        let remaining = downloads.dropFirst()
        if let next = remaining.first {
            let information = try next.information().packet()
            state = .sending(remaining, index: 0)
            return [response, information]
        }
        state = .awaitingDownloaded
        return [response]
    }
}

import Crypto
import Foundation

public enum ResourcePackTransferError: Error, Equatable {
    case emptyArchive
    case invalidChunkSize
    case unexpectedPack
    case invalidChunkIndex
}

public struct ResourcePackArchive: Sendable {
    public let dataInfo: ResourcePackDataInfo
    private let bytes: Data

    public init(id: UUID, bytes: Data, chunkSize: Int = 32_768, packType: UInt8 = 6, premium: Bool = false) throws {
        guard !bytes.isEmpty else { throw ResourcePackTransferError.emptyArchive }
        let overhead = 62 // uuid, chunk fields and batch headers
        guard chunkSize > 0, chunkSize <= BedrockBatch.maximumBytes - overhead else {
            throw ResourcePackTransferError.invalidChunkSize
        }
        guard let count = UInt32(exactly: (bytes.count - 1) / chunkSize + 1) else {
            throw BedrockError.limitExceeded
        }
        dataInfo = ResourcePackDataInfo(
            packID: id.uuidString.lowercased(), chunkSize: UInt32(chunkSize), chunkCount: count,
            size: UInt64(bytes.count), hash: Array(SHA256.hash(data: bytes)), premium: premium, packType: packType
        )
        self.bytes = bytes
    }

    public func chunk(for request: ResourcePackChunkRequest) throws -> ResourcePackChunkData {
        guard request.packID == dataInfo.packID else { throw ResourcePackTransferError.unexpectedPack }
        guard request.index < dataInfo.chunkCount else { throw ResourcePackTransferError.invalidChunkIndex }
        let offset = UInt64(request.index) * UInt64(dataInfo.chunkSize)
        let count = min(UInt64(dataInfo.chunkSize), dataInfo.size - offset)
        let start = bytes.index(bytes.startIndex, offsetBy: Int(offset))
        let end = bytes.index(start, offsetBy: Int(count))
        return ResourcePackChunkData(packID: request.packID, index: request.index, offset: offset, data: Array(bytes[start..<end]))
    }
}

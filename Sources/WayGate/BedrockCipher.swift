import Crypto
import CryptoSwift
import Foundation

struct BedrockCipher {
    private let key: [UInt8]
    private var stream: any Cryptor & Updatable
    private var sequence: UInt64 = 0

    init(key: [UInt8]) throws {
        self.key = key
        let counter = Array(key.prefix(12)) + [0, 0, 0, 2]
        stream = try AES(key: key, blockMode: CTR(iv: counter), padding: .noPadding).makeEncryptor()
    }

    mutating func seal(_ batch: [UInt8]) throws -> [UInt8] {
        guard batch.first == 0xfe else { throw BedrockError.malformed }
        let bytes = batch.dropFirst()
        return [0xfe] + (try stream.update(withBytes: Array(bytes) + checksum(bytes), isLast: false))
    }

    mutating func open(_ batch: [UInt8]) throws -> [UInt8] {
        guard batch.count <= BedrockBatch.maximumBytes + 8 else { throw BedrockError.limitExceeded }
        guard batch.first == 0xfe, batch.count > 9 else { throw BedrockError.malformed }
        let decoded = try stream.update(withBytes: batch.dropFirst(), isLast: false)
        let bytes = decoded.dropLast(8)
        let expected = checksum(bytes)
        let difference = zip(expected, decoded.suffix(8)).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) }
        guard difference == 0 else { throw BedrockError.invalidChecksum }
        return [0xfe] + bytes
    }

    private mutating func checksum(_ payload: ArraySlice<UInt8>) -> [UInt8] {
        var hash = SHA256()
        let count = Swift.withUnsafeBytes(of: sequence.littleEndian) { Array($0) }
        sequence &+= 1
        hash.update(data: Data(count))
        hash.update(data: Data(payload))
        hash.update(data: Data(key))
        return Array(hash.finalize().prefix(8))
    }
}

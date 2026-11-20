import Crypto
import Foundation

enum BedrockJWT {
    static func sign(_ claims: Data, with key: P384.Signing.PrivateKey, includePublicKey: Bool = false) throws -> String {
        var header = ["alg": "ES384"]
        if includePublicKey { header["x5u"] = key.publicKey.derRepresentation.base64EncodedString() }
        let input = try base64URL(JSONEncoder().encode(header)) + "." + base64URL(claims)
        let signature = try key.signature(for: Data(input.utf8)).rawRepresentation
        return input + "." + base64URL(signature)
    }

    static func verifiedPayload(_ token: String, using key: P384.Signing.PublicKey) throws -> Data {
        let parsed = try parse(token)
        guard key.isValidSignature(parsed.signature, for: parsed.input) else { throw BedrockError.invalidClientToken }
        return parsed.payload
    }

    static func declaredKey(_ token: String) throws -> P384.Signing.PublicKey {
        let parsed = try parse(token)
        guard let encoded = parsed.header.x5u, let der = Data(base64Encoded: encoded) else {
            throw BedrockError.invalidClientToken
        }
        return try P384.Signing.PublicKey(derRepresentation: der)
    }

    private static func parse(_ token: String) throws -> SignedToken {
        let compact = try CompactJWT(token)
        guard compact.header.alg == "ES384",
              let signature = try? P384.Signing.ECDSASignature(rawRepresentation: compact.signature) else {
            throw BedrockError.invalidClientToken
        }
        return SignedToken(header: compact.header, payload: compact.payload, signature: signature, input: compact.input)
    }

    private struct SignedToken {
        let header: CompactJWT.Header
        let payload: Data
        let signature: P384.Signing.ECDSASignature
        let input: Data
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ value: Substring) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.utf8.count % 4) % 4)
        guard let data = Data(base64Encoded: base64), base64URL(data) == value else { return nil }
        return data
    }
}

struct CompactJWT {
    struct Header: Decodable {
        let alg: String
        let kid: String?
        let x5u: String?
        let b64: Bool?
        let crit: [String]?
    }

    let header: Header
    let payload: Data
    let signature: Data
    let input: Data

    init(_ token: String) throws {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let json = BedrockJWT.decode(parts[0]),
              let payload = BedrockJWT.decode(parts[1]), !payload.isEmpty,
              let signature = BedrockJWT.decode(parts[2]),
              let header = try? JSONDecoder().decode(Header.self, from: json),
              header.b64 != false, header.crit?.isEmpty != false else { throw BedrockError.invalidClientToken }
        self.header = header
        self.payload = payload
        self.signature = signature
        input = Data(parts.prefix(2).joined(separator: ".").utf8)
    }
}

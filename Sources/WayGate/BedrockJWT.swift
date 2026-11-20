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
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let json = decode(parts[0]), let payload = decode(parts[1]), !payload.isEmpty,
              let raw = decode(parts[2]), let header = try? JSONDecoder().decode(Header.self, from: json),
              header.alg == "ES384", header.b64 != false, header.crit?.isEmpty != false,
              let signature = try? P384.Signing.ECDSASignature(rawRepresentation: raw) else {
            throw BedrockError.invalidClientToken
        }
        let input = Data(parts.prefix(2).joined(separator: ".").utf8)
        return SignedToken(header: header, payload: payload, signature: signature, input: input)
    }

    private struct SignedToken {
        let header: Header
        let payload: Data
        let signature: P384.Signing.ECDSASignature
        let input: Data
    }

    private struct Header: Decodable {
        let alg: String
        let x5u: String?
        let b64: Bool?
        let crit: [String]?
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decode(_ value: Substring) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.utf8.count % 4) % 4)
        guard let data = Data(base64Encoded: base64), base64URL(data) == value else { return nil }
        return data
    }
}

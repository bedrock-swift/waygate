import Crypto
import CryptoExtras
import Foundation

public enum MinecraftLoginTrustError: Error, Equatable {
    case noSigningKeys
    case unknownSigningKey
    case signingKeysUnavailable
}

public struct MinecraftLoginTrust: Sendable {
    public static let issuer = "https://authorization.franchise.minecraft-services.net/"
    public static let audience = "api://auth-minecraft-services/multiplayer"

    private let keys: [String: _RSA.Signing.PublicKey]

    public init(jwks: Data) throws {
        guard jwks.count <= 1024 * 1024 else { throw BedrockError.limitExceeded }
        let set = try JSONDecoder().decode(KeySet.self, from: jwks)
        var keys: [String: _RSA.Signing.PublicKey] = [:]
        var duplicates: Set<String> = []
        for candidate in set.keys {
            guard let key = candidate.key, key.kty == "RSA", key.alg == nil || key.alg == "RS256",
                  key.use == nil || key.use == "sig", !key.kid.isEmpty, !duplicates.contains(key.kid),
                  let modulus = BedrockJWT.decode(key.n[...]), (256...1024).contains(modulus.count),
                  let exponent = BedrockJWT.decode(key.e[...]), (1...8).contains(exponent.count),
                  let publicKey = try? _RSA.Signing.PublicKey(n: modulus, e: exponent),
                  publicKey.keySizeInBits >= 2048 else { continue }
            if keys.updateValue(publicKey, forKey: key.kid) != nil {
                keys.removeValue(forKey: key.kid)
                duplicates.insert(key.kid)
            }
        }
        guard !keys.isEmpty else { throw MinecraftLoginTrustError.noSigningKeys }
        guard keys.count <= 64 else { throw BedrockError.limitExceeded }
        self.keys = keys
    }

    public func verify(_ token: String, at now: Date = .now) throws -> BedrockIdentity {
        guard token.utf8.count <= 64 * 1024 else { throw BedrockError.limitExceeded }
        let jwt = try CompactJWT(token)
        guard jwt.header.alg == "RS256" else { throw BedrockError.invalidIdentity }
        let signature = _RSA.Signing.RSASignature(rawRepresentation: jwt.signature)
        if let id = jwt.header.kid {
            guard let key = keys[id] else { throw MinecraftLoginTrustError.unknownSigningKey }
            guard key.isValidSignature(signature, for: jwt.input, padding: .insecurePKCS1v1_5) else {
                throw BedrockError.untrustedIdentity
            }
        } else {
            guard keys.values.contains(where: { $0.isValidSignature(signature, for: jwt.input, padding: .insecurePKCS1v1_5) }) else {
                throw BedrockError.untrustedIdentity
            }
        }

        let claims = try JSONDecoder().decode(Claims.self, from: jwt.payload)
        let time = now.timeIntervalSince1970
        guard claims.exp > time - 60 else { throw BedrockError.expiredIdentity }
        guard claims.iss == Self.issuer, claims.aud.values.contains(Self.audience), !claims.sub.isEmpty,
              (claims.nbf ?? time) <= time + 60, (claims.iat ?? time) <= time + 60,
              let xuid = UInt64(claims.xid), xuid > 0, claims.xid.utf8.allSatisfy({ (48...57).contains($0) }),
              !claims.xname.isEmpty, let der = Data(base64Encoded: claims.cpk),
              let key = try? P384.Signing.PublicKey(derRepresentation: der) else { throw BedrockError.invalidIdentity }
        return BedrockIdentity(
            id: Self.playerID(for: claims.xid), xuid: claims.xid,
            displayName: claims.xname, publicKeyDER: Array(key.derRepresentation)
        )
    }

    private static func playerID(for xuid: String) -> UUID {
        var hash = Array(Insecure.MD5.hash(data: Data(("pocket-auth-1-xuid:" + xuid).utf8)))
        hash[6] = (hash[6] & 15) | 48 // version 3
        hash[8] = (hash[8] & 63) | 128 // rfc variant
        return UUID(uuid: (
            hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]
        ))
    }

    private struct KeySet: Decodable {
        let keys: [Candidate]
    }

    private struct Candidate: Decodable {
        let key: Key?

        init(from decoder: any Decoder) {
            key = try? Key(from: decoder)
        }
    }

    private struct Key: Decodable {
        let kty: String
        let kid: String
        let alg: String?
        let use: String?
        let n: String
        let e: String
    }

    private struct Claims: Decodable {
        let iss: String
        let sub: String
        let aud: Audience
        let exp: Double
        let nbf: Double?
        let iat: Double?
        let cpk: String
        let xid: String
        let xname: String
    }

    private struct Audience: Decodable {
        let values: [String]

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let name = try? container.decode(String.self) {
                values = [name]
            } else {
                values = try container.decode([String].self)
            }
        }
    }
}

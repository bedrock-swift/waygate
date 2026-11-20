import Crypto
import Foundation

public struct BedrockIdentity: Equatable, Sendable {
    public let id: UUID
    public let xuid: String
    public let displayName: String
    public let publicKeyDER: [UInt8]

    public init(id: UUID, xuid: String, displayName: String, publicKeyDER: [UInt8]) {
        self.id = id
        self.xuid = xuid
        self.displayName = displayName
        self.publicKeyDER = publicKeyDER
    }
}

public struct LegacyLoginTrust: Sendable {
    private let root: P384.Signing.PublicKey

    public init(rootKeyDER: [UInt8]) throws {
        root = try P384.Signing.PublicKey(derRepresentation: rootKeyDER)
    }

    public static func mojang() throws -> LegacyLoginTrust {
        let key = "MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAECRXueJeTDqNRRgJi/vlRufByu/2G0i2Ebt6YMar5QX/R0DIIyrJMcUpruK4QveTfJSTp3Shlq4Gk34cD/4GUWwkv0DVuzeuB+tXija7HBxii03NHDbPAD0AKnLr2wdAp"
        guard let der = Data(base64Encoded: key) else { throw BedrockError.invalidIdentity }
        return try LegacyLoginTrust(rootKeyDER: Array(der))
    }

    public func verify(_ request: LoginRequest, at now: Date = .now) throws -> BedrockIdentity {
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(Envelope.self, from: Data(request.identity))
        guard envelope.AuthenticationType == nil || envelope.AuthenticationType == 0 else {
            throw BedrockError.untrustedIdentity
        }
        let chain: [String]
        if let certificate = envelope.Certificate, !certificate.isEmpty {
            chain = try decoder.decode(Certificate.self, from: Data(certificate.utf8)).chain
        } else {
            chain = envelope.chain ?? []
        }
        guard chain.count == 3 else { throw BedrockError.untrustedIdentity }

        let starter = try BedrockJWT.declaredKey(chain[0])
        let prelude = try Self.claims(of: chain[0], signedBy: starter, at: now)
        guard try prelude.key().x963Representation == root.x963Representation else {
            throw BedrockError.untrustedIdentity
        }

        let delegation = try Self.claims(of: chain[1], signedBy: root, at: now, issuer: "Mojang")
        let player = try Self.claims(of: chain[2], signedBy: delegation.key(), at: now, issuer: "Mojang")
        guard let extra = player.extraData, let id = UUID(uuidString: extra.identity),
              let xuid = UInt64(extra.XUID), xuid > 0, extra.XUID.utf8.allSatisfy({ (48...57).contains($0) }),
              !extra.displayName.isEmpty else { throw BedrockError.invalidIdentity }
        return BedrockIdentity(
            id: id, xuid: extra.XUID, displayName: extra.displayName, publicKeyDER: Array(try player.key().derRepresentation)
        )
    }

    private static func claims(
        of token: String, signedBy key: P384.Signing.PublicKey, at now: Date, issuer: String? = nil
    ) throws -> Claims {
        let payload = try BedrockJWT.verifiedPayload(token, using: key)
        let claims = try JSONDecoder().decode(Claims.self, from: payload)
        let time = now.timeIntervalSince1970
        guard claims.exp > time else { throw BedrockError.expiredIdentity }
        guard (claims.nbf ?? time) <= time, issuer == nil || issuer == claims.iss else {
            throw BedrockError.invalidIdentity
        }
        return claims
    }

    private struct Envelope: Decodable {
        let AuthenticationType: UInt8?
        let Certificate: String?
        let chain: [String]?
    }

    private struct Certificate: Decodable {
        let chain: [String]
    }

    private struct Claims: Decodable {
        let identityPublicKey: String
        let iss: String?
        let exp: Double
        let nbf: Double?
        let extraData: Player?

        func key() throws -> P384.Signing.PublicKey {
            guard let der = Data(base64Encoded: identityPublicKey) else { throw BedrockError.invalidIdentity }
            return try P384.Signing.PublicKey(derRepresentation: der)
        }
    }

    private struct Player: Decodable {
        let displayName: String
        let identity: String
        let XUID: String
    }
}

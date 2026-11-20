import Crypto
import CryptoExtras
import Foundation
import Testing
@testable import WayGate

@Test func verifiesMultiplayerIdentityAndClientKey() throws {
    let signer = try _RSA.Signing.PrivateKey(keySize: .bits2048)
    let client = P384.Signing.PrivateKey().publicKey
    let trust = try MinecraftLoginTrust(jwks: makeJWKS(for: signer.publicKey))
    let expires = 1000.0
    let claims: [String: Any] = [
        "iss": MinecraftLoginTrust.issuer, "sub": "player", "aud": [MinecraftLoginTrust.audience],
        "exp": expires, "iat": 750, "nbf": 800, "cpk": client.derRepresentation.base64EncodedString(),
        "xid": "12345", "xname": "FixturePlayer"
    ]
    let token = try sign(claims, with: signer)
    let identity = try trust.verify(token, at: Date(timeIntervalSince1970: 760))
    #expect(identity.id.uuidString.lowercased() == "f24aef81-9f42-3059-9c39-91ff49cc9bb7")
    #expect(identity.xuid == "12345")
    #expect(identity.displayName == "FixturePlayer")
    #expect(identity.publicKeyDER == Array(client.derRepresentation))
    #expect(throws: BedrockError.expiredIdentity) {
        try trust.verify(token, at: Date(timeIntervalSince1970: expires + 60))
    }
    #expect(throws: BedrockError.invalidIdentity) {
        try trust.verify(token, at: Date(timeIntervalSince1970: 739))
    }

    var wrongAudience = claims
    wrongAudience["aud"] = "another-service"
    let unrelated = try sign(wrongAudience, with: signer)
    #expect(throws: BedrockError.invalidIdentity) {
        try trust.verify(unrelated, at: Date(timeIntervalSince1970: 900))
    }
    let unknown = try sign(claims, with: signer, kid: "unknown")
    #expect(throws: MinecraftLoginTrustError.unknownSigningKey) {
        try trust.verify(unknown, at: Date(timeIntervalSince1970: 900))
    }
    let parts = token.split(separator: ".")
    let altered = [String(parts[0]), BedrockJWT.base64URL(try JSONSerialization.data(withJSONObject: wrongAudience)), String(parts[2])]
        .joined(separator: ".")
    #expect(throws: BedrockError.untrustedIdentity) {
        try trust.verify(altered, at: Date(timeIntervalSince1970: 900))
    }
}

@Test func ignoresMalformedKeysAndRejectsAmbiguousKeyIDs() throws {
    let signer = try _RSA.Signing.PrivateKey(keySize: .bits2048)
    _ = try MinecraftLoginTrust(jwks: makeJWKS(for: signer.publicKey))
    #expect(throws: MinecraftLoginTrustError.noSigningKeys) {
        try MinecraftLoginTrust(jwks: makeJWKS(for: signer.publicKey, duplicate: true))
    }
}

@Test func refreshesRotatedKeysAndBoundsStaleTrust() async throws {
    let original = try _RSA.Signing.PrivateKey(keySize: .bits2048)
    let rotated = try _RSA.Signing.PrivateKey(keySize: .bits2048)
    let initialTrust = try MinecraftLoginTrust(jwks: makeJWKS(for: original.publicKey))
    let rotatedTrust = try MinecraftLoginTrust(jwks: makeJWKS(for: rotated.publicKey, kid: "rotated"))
    let source = KeySource(initialTrust)
    let keys = try await MinecraftLoginKeys(fetching: { try source.fetch() }, clock: { source.now })
    let client = P384.Signing.PrivateKey().publicKey
    let date = Date(timeIntervalSince1970: 900)
    let claims: [String: Any] = [
        "iss": MinecraftLoginTrust.issuer, "sub": "player", "aud": MinecraftLoginTrust.audience,
        "exp": 1000, "cpk": client.derRepresentation.base64EncodedString(), "xid": "12345", "xname": "FixturePlayer"
    ]
    let token = try sign(claims, with: rotated, kid: "rotated")

    source.set(rotatedTrust, after: .seconds(60))
    let identity = try await keys.verify(token, at: date)
    #expect(identity.xuid == "12345")

    source.set(nil, after: .seconds(3600))
    #expect(try await keys.verify(token, at: date) == identity)

    source.set(nil, after: .seconds(18_000))
    await #expect(throws: MinecraftLoginTrustError.signingKeysUnavailable) {
        try await keys.verify(token, at: date)
    }
}

private final class KeySource: @unchecked Sendable {
    private let lock = NSLock()
    private var instant = ContinuousClock.now
    private var trust: MinecraftLoginTrust?

    init(_ trust: MinecraftLoginTrust) {
        self.trust = trust
    }

    var now: ContinuousClock.Instant { lock.withLock { instant } }

    func set(_ trust: MinecraftLoginTrust?, after duration: Duration) {
        lock.withLock {
            self.trust = trust
            instant = instant.advanced(by: duration)
        }
    }

    func fetch() throws -> MinecraftLoginTrust {
        try lock.withLock {
            guard let trust else { throw MinecraftLoginTrustError.signingKeysUnavailable }
            return trust
        }
    }
}

private func makeJWKS(for key: _RSA.Signing.PublicKey, kid: String = "fixture", duplicate: Bool = false) throws -> Data {
    let fields = try key.getKeyPrimitives()
    let active = [
        "kty": "RSA", "kid": kid, "use": "sig",
        "n": BedrockJWT.base64URL(fields.modulus), "e": BedrockJWT.base64URL(fields.publicExponent)
    ]
    var keys: [Any] = [false, ["kty": "RSA"], active]
    if duplicate { keys.append(active) }
    return try JSONSerialization.data(withJSONObject: ["keys": keys])
}

private func sign(_ claims: [String: Any], with signer: _RSA.Signing.PrivateKey, kid: String = "fixture") throws -> String {
    let header = try JSONEncoder().encode(["alg": "RS256", "kid": kid])
    let payload = try JSONSerialization.data(withJSONObject: claims)
    let input = BedrockJWT.base64URL(header) + "." + BedrockJWT.base64URL(payload)
    let signature = try signer.signature(for: Data(input.utf8), padding: .insecurePKCS1v1_5)
    return input + "." + BedrockJWT.base64URL(signature.rawRepresentation)
}

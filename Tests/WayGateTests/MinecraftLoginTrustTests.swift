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

private func makeJWKS(for key: _RSA.Signing.PublicKey, duplicate: Bool = false) throws -> Data {
    let fields = try key.getKeyPrimitives()
    let active = [
        "kty": "RSA", "kid": "fixture", "use": "sig",
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

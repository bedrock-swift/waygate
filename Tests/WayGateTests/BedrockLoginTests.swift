import Crypto
import Foundation
import RakNet
import Testing
@testable import WayGate

enum LoginMode: Sendable {
    case certificateChain
    case multiplayerToken
}

@Test(.timeLimit(.minutes(1)), arguments: [LoginMode.certificateChain, .multiplayerToken])
func raknetLoginNegotiatesAnEncryptedBedrockSession(_ mode: LoginMode) async throws {
    let signing = P384.Signing.PrivateKey()
    let key = try P384.KeyAgreement.PrivateKey(rawRepresentation: signing.rawRepresentation)
    let clientClaims = Data(#"{"DeviceOS":7}"#.utf8)
    let token = try BedrockJWT.sign(clientClaims, with: signing)
    let login: BedrockLoginServer
    let loginPacket: BedrockPacket
    switch mode {
    case .certificateChain:
        let fixture = try IdentityFixture(client: signing)
        login = BedrockLoginServer(trust: fixture.trust)
        loginPacket = try fixture.packet(clientToken: token)
    case .multiplayerToken:
        let id = try #require(UUID(uuidString: "2ac55962-b2b2-4cfc-83e4-b27250f26cb3"))
        let identity = BedrockIdentity(
            id: id, xuid: "12345", displayName: "FixturePlayer", publicKeyDER: Array(signing.publicKey.derRepresentation)
        )
        login = .multiplayer { presented in
            guard presented == "header.payload.signature" else { throw BedrockError.untrustedIdentity }
            return identity
        }
        #expect(login.protocolVersion == 2225)
        let envelope = Data(#"{"AuthenticationType":0,"Token":"header.payload.signature"}"#.utf8)
        loginPacket = try makeLoginPacket(protocolVersion: 2225, envelope: envelope, clientToken: token)
    }
    let loopback = RakNetEndpoint.ipv4(IPv4Endpoint(address: 0x7f000001, port: 0))
    let listener = try BedrockListener(on: loopback, login: login)
    defer { listener.close() }

    let client = try await RakNetConnection.dial(listener.localAddress)
    var version: [UInt8] = []
    version.appendBigEndian(login.protocolVersion)
    let settingsRequest = try BedrockPacket(id: 193, payload: version)
    try await client.send(BedrockBatch.encode([settingsRequest]))
    let settings = try #require(try await client.receive())
    #expect(settings == [0xfe, 12, 0x8f, 1, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0])

    try await client.send(BedrockBatch.encode([loginPacket], framing: .negotiated))

    let encoded = try #require(try await client.receive())
    let handshake = try #require(try BedrockBatch.decode(encoded, framing: .negotiated).first)
    #expect(handshake.id == 3)
    var payload = BedrockReader(handshake.payload[...])
    let tokenLength = try payload.varUInt()
    let serverToken = String(decoding: try payload.read(Int(tokenLength)), as: UTF8.self)
    let pieces = serverToken.split(separator: ".")
    try #require(pieces.count == 3)
    let header = try JSONDecoder().decode([String: String].self, from: decode(pieces[0]))
    let claims = try JSONDecoder().decode([String: String].self, from: decode(pieces[1]))
    #expect(header["alg"] == "ES384")
    let keyDER = try #require(Data(base64Encoded: header["x5u"] ?? ""))
    let serverKey = try P384.Signing.PublicKey(derRepresentation: keyDER)
    let signature = try P384.Signing.ECDSASignature(rawRepresentation: decode(pieces[2]))
    let input = Data((String(pieces[0]) + "." + String(pieces[1])).utf8)
    #expect(serverKey.isValidSignature(signature, for: input))

    let remote = try P384.KeyAgreement.PublicKey(derRepresentation: keyDER)
    let shared = try key.sharedSecretFromKeyAgreement(with: remote)
    let salt = try decode(try #require(claims["salt"])[...])
    let sessionKey = Array(SHA256.hash(data: salt + shared.withUnsafeBytes { Data($0) }))
    var seal = try BedrockCipher(key: sessionKey)
    var open = try BedrockCipher(key: sessionKey)
    try await client.send(seal.seal([0xfe, 0xff, 1, 4]))

    var sessions = listener.connections.makeAsyncIterator()
    let session = try #require(try await sessions.next())
    #expect(session.clientData == clientClaims)
    #expect(session.identity?.displayName == "FixturePlayer")
    #expect(session.identity?.xuid == "12345")
    let status = try #require(try await client.receive())
    let decryptedStatus = try open.open(status)
    #expect(decryptedStatus == [0xfe, 0xff, 5, 2, 0, 0, 0, 0])

    try await exchangeResourcePack(
        with: session, client: client, seal: &seal, open: &open,
        format: mode == .certificateChain ? .legacy : .v26_60
    )

    let message = try BedrockPacket(id: 9, payload: Array(repeating: 50, count: 20_100))
    try await client.send(seal.seal(BedrockBatch.encode([message], framing: .negotiated)))
    let received = try await session.receive()
    #expect(received == [message])
    try await session.send([message])
    let reply = try #require(try await client.receive())
    let decryptedReply = try open.open(reply)
    #expect(try BedrockBatch.decode(decryptedReply, framing: .negotiated) == [message])
    await session.close()
}

private func exchangeResourcePack(
    with session: BedrockSession, client: RakNetConnection, seal: inout BedrockCipher, open: inout BedrockCipher,
    format: ResourcePackFormat
) async throws {
    func send(_ packets: [BedrockPacket]) async throws {
        try await client.send(seal.seal(BedrockBatch.encode(packets, framing: .negotiated)))
    }
    func receive() async throws -> BedrockPacket {
        let wire = try #require(try await client.receive())
        let packets = try BedrockBatch.decode(open.open(wire), framing: .negotiated)
        try #require(packets.count == 1)
        return try #require(packets.first)
    }

    let id = try #require(UUID(uuidString: "11111111-1111-4111-8111-111111111111"))
    let archive = try ResourcePackArchive(id: id, bytes: Data([1, 2, 3]))
    let packID = archive.dataInfo.packID
    let info = ResourcePacksInfo(texturePacks: [.init(id: id, version: "1.0.0", size: 3)])
    let stack = ResourcePackStack(texturePacks: [.init(id: packID, version: "1.0.0")], baseGameVersion: "1.26.60")
    let exchange = try ResourcePackNegotiation(info: info, stack: stack, archives: [archive], format: format)
    async let trailing = session.negotiateResourcePacks(exchange)

    let cache = try BedrockPacket(id: 129, payload: [1])
    try await send([cache])
    #expect(try await receive() == info.packet(format: format))
    await #expect(throws: BedrockError.concurrentOperation) { try await session.receive() }
    try await send([ResourcePackClientResponse(status: .sendPacks, packIDs: [packID]).packet(format: format)])
    #expect(try await receive() == archive.dataInfo.packet())
    try await send([ResourcePackChunkRequest(packID: packID, index: 0).packet(format: format)])
    let chunk = try await receive()
    #expect(try ResourcePackChunkData(decoding: chunk).data == [1, 2, 3])
    try await send([ResourcePackClientResponse(status: .allPacksDownloaded).packet(format: format)])
    #expect(try await receive() == stack.packet(format: format))

    let game = try BedrockPacket(id: 9, payload: [1])
    try await send([ResourcePackClientResponse(status: .completed).packet(format: format), game])
    let pending = try await trailing
    #expect(pending == [game])
    #expect(await session.clientCacheEnabled == true)
}

@Test func rejectsGuestAndEmptyMultiplayerCredentials() throws {
    for envelope in [
        #"{"AuthenticationType":1,"Token":"header.payload.signature"}"#,
        #"{"AuthenticationType":2,"Token":"header.payload.signature"}"#,
        #"{"AuthenticationType":0,"Token":""}"#
    ] {
        let packet = try makeLoginPacket(protocolVersion: 2225, envelope: Data(envelope.utf8), clientToken: "client")
        let request = try LoginRequest(decoding: packet)
        #expect(throws: BedrockError.untrustedIdentity) { try request.multiplayerToken() }
    }
}

private func decode(_ base64: Substring) throws -> Data {
    var value = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    value += String(repeating: "=", count: (4 - value.utf8.count % 4) % 4)
    return try #require(Data(base64Encoded: value))
}

@Test(.timeLimit(.minutes(1))) func loginDeadlineClosesASilentPeer() async throws {
    let loopback = RakNetEndpoint.ipv4(IPv4Endpoint(address: 0x7f000001, port: 0))
    let listener = try RakNetListener.listen(on: loopback)
    defer { listener.close() }
    let client = try await RakNetConnection.dial(listener.localAddress)
    let peer = try #require(try await listener.accept())
    let login = BedrockLoginServer { _ in throw BedrockError.malformed }
    await #expect(throws: BedrockError.timedOut) {
        try await login.accept(on: peer, timeout: .milliseconds(30))
    }
    try await client.close()
}

@Test func clientDataSignedWithAnotherKeyIsRejected() throws {
    let client = P384.Signing.PrivateKey()
    let other = P384.Signing.PrivateKey()
    let token = try BedrockJWT.sign(Data("claims".utf8), with: client)
    #expect(throws: BedrockError.invalidClientToken) {
        try BedrockJWT.verifiedPayload(token, using: other.publicKey)
    }
}

@Test func identityRejectsAnUntrustedOrExpiredChain() throws {
    let client = P384.Signing.PrivateKey()
    let now = Date(timeIntervalSince1970: 200)
    let fixture = try IdentityFixture(client: client, expires: 300)
    let request = try LoginRequest(decoding: fixture.packet(clientToken: "signed-by-client"))
    let identity = try fixture.trust.verify(request, at: now)
    #expect(identity.publicKeyDER == Array(client.publicKey.derRepresentation))

    let anotherRoot = P384.Signing.PrivateKey()
    let other = try LegacyLoginTrust(rootKeyDER: Array(anotherRoot.publicKey.derRepresentation))
    #expect(throws: BedrockError.untrustedIdentity) { try other.verify(request, at: now) }
    #expect(throws: BedrockError.expiredIdentity) {
        try fixture.trust.verify(request, at: Date(timeIntervalSince1970: 300))
    }
}

private struct IdentityFixture {
    let trust: LegacyLoginTrust
    let envelope: Data

    init(client: P384.Signing.PrivateKey, expires: Double = Date.now.timeIntervalSince1970 + 300) throws {
        let root = P384.Signing.PrivateKey()
        let delegation = P384.Signing.PrivateKey()
        trust = try LegacyLoginTrust(rootKeyDER: Array(root.publicKey.derRepresentation))
        func issue(_ signer: P384.Signing.PrivateKey, successor: P384.Signing.PublicKey, claims: [String: Any]) throws -> String {
            var body = claims
            body["identityPublicKey"] = successor.derRepresentation.base64EncodedString()
            body["exp"] = expires
            return try BedrockJWT.sign(JSONSerialization.data(withJSONObject: body), with: signer, includePublicKey: true)
        }
        let chain = try [
            issue(client, successor: root.publicKey, claims: [:]),
            issue(root, successor: delegation.publicKey, claims: ["iss": "Mojang"]),
            issue(delegation, successor: client.publicKey, claims: [
                "iss": "Mojang",
                "extraData": ["displayName": "FixturePlayer", "identity": "2ac55962-b2b2-4cfc-83e4-b27250f26cb3", "XUID": "12345"]
            ])
        ]
        let certificate = try JSONEncoder().encode(["chain": chain])
        envelope = try JSONSerialization.data(withJSONObject: [
            "AuthenticationType": 0, "Certificate": String(decoding: certificate, as: UTF8.self)
        ])
    }

    func packet(clientToken: String) throws -> BedrockPacket {
        let version = BedrockLoginServer(trust: trust).protocolVersion
        return try makeLoginPacket(protocolVersion: version, envelope: envelope, clientToken: clientToken)
    }
}

private func makeLoginPacket(protocolVersion: Int32, envelope: Data, clientToken: String) throws -> BedrockPacket {
    var request: [UInt8] = []
    for field in [Array(envelope), Array(clientToken.utf8)] {
        request.appendLittleEndian(UInt32(field.count))
        request += field
    }
    var payload: [UInt8] = []
    payload.appendBigEndian(protocolVersion)
    payload.appendVarUInt(UInt32(request.count))
    payload += request
    return try BedrockPacket(id: 1, payload: payload)
}

@Test(arguments: [true, false])
func nethernetLoginRequiresTheAuthenticatedTransportKey(_ matching: Bool) async throws {
    let signing = P384.Signing.PrivateKey()
    let authenticatedKey = matching ? signing.publicKey : P384.Signing.PrivateKey().publicKey
    let clientData = Data(#"{"DeviceOS":7}"#.utf8)
    let clientToken = try BedrockJWT.sign(clientData, with: signing)
    let login = BedrockLoginServer(protocolVersion: 2225) { _ in Array(signing.publicKey.derRepresentation) }
    let envelope = Data(#"{"AuthenticationType":0,"Token":"header.payload.signature"}"#.utf8)
    let request = try makeLoginPacket(protocolVersion: 2225, envelope: envelope, clientToken: clientToken)
    let settings = try BedrockPacket(id: 193, payload: [0, 0, 8, 0xb1])
    let transport = LoginTransport([
        try BedrockBatch.encode([settings], transport: .nethernet),
        try BedrockBatch.encode([request], framing: .negotiated, transport: .nethernet)
    ])
    let key = Array(authenticatedKey.derRepresentation)

    if matching {
        let session = try await login.acceptNetherNet(on: transport, authenticatedKey: key)
        #expect(session.clientData == clientData)
        let replies = await transport.replies
        try #require(replies.count == 2)
        #expect(replies[0] == [12, 0x8f, 1, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0])
        #expect(replies[1] == [0xff, 5, 2, 0, 0, 0, 0])
        await session.close()
    } else {
        await #expect(throws: BedrockError.untrustedIdentity) {
            try await login.acceptNetherNet(on: transport, authenticatedKey: key)
        }
        #expect(await transport.replies.count == 1)
        #expect(await transport.closed)
    }
}

private actor LoginTransport: BedrockTransport {
    private var requests: ArraySlice<[UInt8]>
    private(set) var replies: [[UInt8]] = []
    private(set) var closed = false

    init(_ requests: [[UInt8]]) {
        self.requests = requests[...]
    }

    func receive() async throws -> [UInt8]? { requests.popFirst() }
    func send(_ payload: [UInt8]) async throws { replies.append(payload) }
    func close() async { closed = true }
}

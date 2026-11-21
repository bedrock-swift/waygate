import Crypto
import Foundation

public struct BedrockLoginServer: Sendable {
    public let protocolVersion: Int32
    private let verify: @Sendable (LoginRequest) async throws -> (key: [UInt8], identity: BedrockIdentity?)

    public init(protocolVersion: Int32 = 819, verify: @escaping @Sendable (LoginRequest) async throws -> [UInt8]) {
        self.init(protocolVersion: protocolVersion, verification: { (try await verify($0), nil) })
    }

    public init(protocolVersion: Int32 = 819, trust: LegacyLoginTrust) {
        self.init(protocolVersion: protocolVersion, verification: { request in
            let identity = try trust.verify(request)
            return (identity.publicKeyDER, identity)
        })
    }

    public static func multiplayer(
        protocolVersion: Int32 = 2225, verifying verifyToken: @escaping @Sendable (String) async throws -> BedrockIdentity
    ) -> BedrockLoginServer {
        BedrockLoginServer(protocolVersion: protocolVersion, verification: { request in
            let identity = try await verifyToken(request.multiplayerToken())
            return (identity.publicKeyDER, identity)
        })
    }

    public static func multiplayer(protocolVersion: Int32 = 2225, keys: MinecraftLoginKeys) -> BedrockLoginServer {
        multiplayer(protocolVersion: protocolVersion, verifying: keys.verify)
    }

    private init(
        protocolVersion: Int32,
        verification: @escaping @Sendable (LoginRequest) async throws -> (key: [UInt8], identity: BedrockIdentity?)
    ) {
        self.protocolVersion = protocolVersion
        verify = verification
    }

    public func accept(on transport: any BedrockTransport, timeout: Duration = .seconds(10)) async throws -> BedrockSession {
        try await accept(on: transport, nethernetKey: nil, timeout: timeout)
    }

    public func acceptNetherNet(
        on transport: any BedrockTransport, authenticatedKey: [UInt8], timeout: Duration = .seconds(10)
    ) async throws -> BedrockSession {
        try await accept(on: transport, nethernetKey: authenticatedKey, timeout: timeout)
    }

    private func accept(
        on transport: any BedrockTransport, nethernetKey: [UInt8]?, timeout: Duration
    ) async throws -> BedrockSession {
        guard timeout > .zero else {
            try? await transport.close()
            throw BedrockError.timedOut
        }
        return try await withThrowingTaskGroup(of: BedrockSession.self) { negotiation in
            negotiation.addTask { try await negotiate(on: transport, nethernetKey: nethernetKey) }
            negotiation.addTask {
                try await Task.sleep(for: timeout)
                throw BedrockError.timedOut
            }
            defer { negotiation.cancelAll() }
            do {
                guard let session = try await negotiation.next() else { throw BedrockError.closed }
                return session
            } catch {
                negotiation.cancelAll()
                try? await transport.close()
                throw error
            }
        }
    }

    private func negotiate(on transport: any BedrockTransport, nethernetKey: [UInt8]?) async throws -> BedrockSession {
        let batchTransport: BedrockBatch.Transport = nethernetKey == nil ? .raknet : .nethernet
        let settings = try await packet(
            id: RequestNetworkSettings.packetID, on: transport, framing: .initial, batchTransport: batchTransport
        )
        let requested = try RequestNetworkSettings(decoding: settings).protocolVersion
        if requested != protocolVersion {
            try await sendStatus(requested < protocolVersion ? .failedClient : .failedServer, on: transport, batchTransport: batchTransport)
            throw BedrockError.unsupportedProtocol(requested)
        }
        let threshold = UInt16(BedrockBatch.compressionThreshold)
        let response = try NetworkSettings(compressionThreshold: threshold, compression: .snappy).packet()
        try await transport.send(BedrockBatch.encode([response], transport: batchTransport))

        let login = try await LoginRequest(decoding: packet(
            id: 1, on: transport, framing: .negotiated, batchTransport: batchTransport
        ))
        guard login.protocolVersion == protocolVersion else { throw BedrockError.unsupportedProtocol(login.protocolVersion) }
        let verified = try await verify(login)
        let signingKey = try P384.Signing.PublicKey(derRepresentation: verified.key)
        let clientData = try BedrockJWT.verifiedPayload(login.clientToken, using: signingKey)
        if let nethernetKey {
            guard Array(signingKey.derRepresentation) == nethernetKey else { throw BedrockError.untrustedIdentity }
            let session = try BedrockSession(
                transport: transport, login: login, identity: verified.identity, clientData: clientData,
                batchTransport: batchTransport, key: nil
            )
            try await session.send([try PlayStatus.loginSuccess.packet()])
            return session
        }

        let key = try P384.KeyAgreement.PublicKey(x963Representation: signingKey.x963Representation)
        let handshake = try Self.handshake(with: key)
        try await transport.send(BedrockBatch.encode([handshake.packet], framing: .negotiated))

        let session = try BedrockSession(
            transport: transport, login: login, identity: verified.identity, clientData: clientData,
            batchTransport: batchTransport, key: handshake.key
        )
        guard let acknowledgement = try await session.receive(), acknowledgement.count == 1,
              let received = acknowledgement.first, received.id == 4, received.sender == 0, received.target == 0,
              received.payload.isEmpty else { throw BedrockError.malformed }
        try await session.send([try PlayStatus.loginSuccess.packet()])
        return session
    }

    private func packet(
        id: UInt16, on transport: any BedrockTransport, framing: BedrockBatch.Framing, batchTransport: BedrockBatch.Transport
    ) async throws -> BedrockPacket {
        guard let bytes = try await transport.receive() else { throw BedrockError.closed }
        let batch = try BedrockBatch.decode(bytes, framing: framing, transport: batchTransport)
        guard batch.count == 1, let packet = batch.first, packet.sender == 0, packet.target == 0 else {
            throw BedrockError.malformed
        }
        guard packet.id == id else { throw BedrockError.unexpectedPacket(packet.id) }
        return packet
    }

    private func sendStatus(
        _ status: PlayStatus, on transport: any BedrockTransport, batchTransport: BedrockBatch.Transport
    ) async throws {
        try await transport.send(BedrockBatch.encode([try status.packet()], transport: batchTransport))
    }

    private static func handshake(with remote: P384.KeyAgreement.PublicKey) throws -> (packet: BedrockPacket, key: [UInt8]) {
        let signing = P384.Signing.PrivateKey()
        let agreement = try P384.KeyAgreement.PrivateKey(rawRepresentation: signing.rawRepresentation)
        let salt = (0..<16).map { _ in UInt8.random(in: .min ... .max) }
        let secret = try agreement.sharedSecretFromKeyAgreement(with: remote)
        let key = Array(SHA256.hash(data: Data(salt + secret.withUnsafeBytes { Array($0) })))

        let claims = ["salt": Data(salt).base64EncodedString().replacingOccurrences(of: "=", with: "")]
        let token = try Array(BedrockJWT.sign(JSONEncoder().encode(claims), with: signing, includePublicKey: true).utf8)
        var payload: [UInt8] = []
        payload.appendVarUInt(UInt32(token.count))
        payload += token
        return (try BedrockPacket(id: 3, payload: payload), key)
    }
}

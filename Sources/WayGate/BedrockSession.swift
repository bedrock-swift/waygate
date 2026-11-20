import Foundation
import RakNet

public protocol BedrockTransport: Sendable {
    func receive() async throws -> [UInt8]?
    func send(_ payload: [UInt8]) async throws
    func close() async throws
}

extension RakNetConnection: BedrockTransport {}

public actor BedrockSession {
    private let transport: any BedrockTransport
    private var incoming: BedrockCipher
    private var outgoing: BedrockCipher
    private var receiving = false
    private var sending = false
    private var closed = false

    public nonisolated let login: LoginRequest
    public nonisolated let identity: BedrockIdentity?
    public nonisolated let clientData: Data

    init(
        transport: any BedrockTransport, login: LoginRequest, identity: BedrockIdentity?, clientData: Data, key: [UInt8]
    ) throws {
        self.transport = transport
        self.login = login
        self.identity = identity
        self.clientData = clientData
        incoming = try BedrockCipher(key: key)
        outgoing = try BedrockCipher(key: key)
    }

    public func receive() async throws -> [BedrockPacket]? {
        guard !closed else { return nil }
        guard !receiving else { throw BedrockError.concurrentOperation }
        receiving = true
        defer { receiving = false }
        do {
            guard let bytes = try await transport.receive(), !closed else {
                await close()
                return nil
            }
            return try BedrockBatch.decode(incoming.open(bytes), framing: .negotiated)
        } catch {
            await close()
            throw error
        }
    }

    public func send(_ packets: [BedrockPacket]) async throws {
        guard !closed else { throw BedrockError.closed }
        guard !sending else { throw BedrockError.concurrentOperation }
        let bytes = try BedrockBatch.encode(packets, framing: .negotiated)
        sending = true
        defer { sending = false }
        do {
            try await transport.send(outgoing.seal(bytes))
        } catch {
            await close()
            throw error
        }
    }

    public func close() async {
        guard !closed else { return }
        closed = true
        try? await transport.close()
    }
}

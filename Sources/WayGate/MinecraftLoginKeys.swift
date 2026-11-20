import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor MinecraftLoginKeys {
    private static let url = URL(string: MinecraftLoginTrust.issuer + ".well-known/keys")!
    private let fetch: @Sendable () async throws -> MinecraftLoginTrust
    private let clock: @Sendable () -> ContinuousClock.Instant
    private var trust: MinecraftLoginTrust
    private var refreshedAt: ContinuousClock.Instant
    private var attemptedAt: ContinuousClock.Instant
    private var refresh: Task<MinecraftLoginTrust, any Error>?

    public init() async throws {
        try await self.init(fetching: Self.fetchKeys)
    }

    init(
        fetching: @escaping @Sendable () async throws -> MinecraftLoginTrust,
        clock: @escaping @Sendable () -> ContinuousClock.Instant = { .now }
    ) async throws {
        fetch = fetching
        self.clock = clock
        trust = try await fetching()
        refreshedAt = clock()
        attemptedAt = refreshedAt
    }

    public func verify(_ token: String) async throws -> BedrockIdentity {
        try await verify(token, at: .now)
    }

    func verify(_ token: String, at date: Date) async throws -> BedrockIdentity {
        try Task.checkCancellation()
        let age = refreshedAt.duration(to: clock())
        if age >= .seconds(21_600) {
            guard let refresh = startRefresh() else { throw MinecraftLoginTrustError.signingKeysUnavailable }
            let updated = try await refresh.value
            try Task.checkCancellation()
            return try updated.verify(token, at: date)
        }
        do {
            let identity = try trust.verify(token, at: date)
            if age >= .seconds(3600) { _ = startRefresh() }
            return identity
        } catch MinecraftLoginTrustError.unknownSigningKey {
            guard let refresh = startRefresh() else { throw MinecraftLoginTrustError.unknownSigningKey }
            let updated = try await refresh.value
            try Task.checkCancellation()
            return try updated.verify(token, at: date)
        }
    }

    private func startRefresh() -> Task<MinecraftLoginTrust, any Error>? {
        if let refresh { return refresh }
        let attempt = clock()
        guard attemptedAt.duration(to: attempt) >= .seconds(60) else { return nil }
        attemptedAt = attempt
        let task = Task { try await performRefresh() }
        refresh = task
        return task
    }

    private func performRefresh() async throws -> MinecraftLoginTrust {
        defer { refresh = nil }
        let updated = try await fetch()
        trust = updated
        refreshedAt = clock()
        return updated
    }

    private static func fetchKeys() async throws -> MinecraftLoginTrust {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (body, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MinecraftLoginTrustError.signingKeysUnavailable
        }
        return try MinecraftLoginTrust(jwks: body)
    }
}

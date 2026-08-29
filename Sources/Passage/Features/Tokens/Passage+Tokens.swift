import Foundation
import JWT
import Vapor

extension Passage {

    struct Tokens: Sendable {
        let request: Request
    }

}

// MARK: - Request Extension

extension Request {
    var tokens: Passage.Tokens {
        Passage.Tokens(request: self)
    }
}

// MARK: - Service Accessors

extension Passage.Tokens {

    var store: any Passage.Store {
        request.store
    }

    var configuration: Passage.Configuration.Tokens {
        request.configuration.tokens
    }

    var random: any Passage.RandomGenerator {
        request.random
    }

}

// MARK: - Issue Token

extension Passage.Tokens {

    func issue(
        for user: any User,
        sessionId: UUID,
        origin: CredentialIssuance.Origin
    ) async throws -> AuthUser {
        try await mint(
            for: user,
            sessionId: sessionId,
            origin: origin,
            replacing: nil
        )
    }

}

// MARK: - Refresh Token

extension Passage.Tokens {

    func refresh(using opaqueRefreshToken: String) async throws -> AuthUser {
        let hash = random.hashOpaqueToken(token: opaqueRefreshToken)

        guard let refreshToken = try await store.tokens.find(refreshTokenHash: hash) else {
            throw AuthenticationError.refreshTokenNotFound
        }

        guard refreshToken.isValid else {
            try await store.tokens.revoke(refreshTokenFamilyStartingFrom: refreshToken)
            throw AuthenticationError.invalidRefreshToken
        }

        return try await mint(
            for: refreshToken.user,
            sessionId: refreshToken.sessionId,
            origin: .refresh,
            replacing: refreshToken
        )
    }

}

// MARK: - Mint

extension Passage.Tokens {

    private func mint(
        for user: any User,
        sessionId: UUID,
        origin: CredentialIssuance.Origin,
        replacing tokenToReplace: (any RefreshToken)?
    ) async throws -> AuthUser {
        let now = Date.now
        let accessTokenExpiresAt = now.addingTimeInterval(configuration.accessToken.timeToLive)
        let refreshTokenExpiresAt = now.addingTimeInterval(configuration.refreshToken.timeToLive)

        let accessToken = AccessToken(
            userId: try user.requiredIdAsString,
            issuedAt: now,
            expiresAt: accessTokenExpiresAt,
            issuer: configuration.issuer,
            audience: nil,
            scope: nil,
            sessionId: sessionId
        )
        let signedAccessToken = try await request.jwt.sign(accessToken)

        let opaqueToken = random.generateOpaqueToken()
        let opaqueTokenHash = random.hashOpaqueToken(token: opaqueToken)

        let request = self.request
        let hooks = request.hooks.account

        let issuance = try await store.transaction { store in
            let revokedSessionIds: [UUID]
            if tokenToReplace != nil {
                revokedSessionIds = []
            } else {
                switch configuration.refreshToken.concurrency {
                case .unlimited:
                    revokedSessionIds = []
                case .single:
                    revokedSessionIds = try await store.tokens.revokeRefreshTokens(for: user)
                case .limit(let n):
                    revokedSessionIds = try await store.tokens.revokeRefreshTokens(for: user, keepingNewestSessions: n - 1)
                }
            }

            try await store.tokens.createRefreshToken(
                for: user,
                tokenHash: opaqueTokenHash,
                expiresAt: refreshTokenExpiresAt,
                sessionId: sessionId,
                replacing: tokenToReplace
            )

            let issuance = CredentialIssuance(
                kind: .bearer,
                origin: origin,
                user: user,
                sessionId: sessionId,
                accessToken: signedAccessToken,
                accessTokenExpiresAt: accessTokenExpiresAt,
                refreshTokenExpiresAt: refreshTokenExpiresAt,
                revokedSessionIds: revokedSessionIds,
                store: store
            )

            try await hooks?.willIssueCredential(issuance, on: request)

            return issuance
        }

        await hooks?.didIssueCredential(issuance, on: request)

        return AuthUser(
            accessToken: signedAccessToken,
            refreshToken: opaqueToken,
            tokenType: "Bearer",
            expiresIn: configuration.accessToken.timeToLive,
            user: .init(
                id: try user.requiredIdAsString,
                email: user.email,
                phone: user.phone
            )
        )
    }

}

// MARK: - Revoke Token

extension Passage.Tokens {

    func revoke(for user: any User) async throws {
        try await store.tokens.revokeRefreshTokens(for: user)
    }

    func revoke(sessionId: UUID) async throws {
        try await store.tokens.revokeRefreshTokens(sessionId: sessionId)
    }

}

// MARK: - Exchange Token Generation

extension Passage.Tokens {

    /// Create exchange token and return the plain-text code.
    /// Used by OAuth flows to generate temporary code for redirect URL.
    /// - Parameter user: User to create exchange token for
    /// - Returns: Plain-text exchange code (to include in redirect URL)
    func createExchangeCode(for user: any User) async throws -> String {
        // Generate random code (URL-safe)
        let code = random.generateOpaqueToken()

        // Hash it before storing
        let hash = random.hashOpaqueToken(token: code)

        // Create exchange token with short TTL (60 seconds)
        let expiresAt = Date().addingTimeInterval(60)

        try await store.exchangeTokens.createExchangeToken(
            for: user,
            tokenHash: hash,
            expiresAt: expiresAt
        )

        // Return plain-text code for redirect URL
        return code
    }
}

// MARK: - Exchange Token Consumption

extension Passage.Tokens {

    /// Exchange temporary code for full JWT tokens.
    /// - Parameter code: Plain-text exchange code from redirect URL
    /// - Returns: AuthUser with access and refresh tokens
    func exchange(code: String) async throws -> AuthUser {
        // Hash the provided code
        let hash = random.hashOpaqueToken(token: code)

        // Find exchange token
        guard let exchangeToken = try await store.exchangeTokens.find(exchangeTokenHash: hash) else {
            throw Abort(.unauthorized, reason: "Invalid exchange code")
        }

        // Validate token
        guard exchangeToken.isValid else {
            if exchangeToken.isExpired {
                throw Abort(.unauthorized, reason: "Exchange code has expired")
            } else {
                throw Abort(.unauthorized, reason: "Exchange code has already been used")
            }
        }

        // Mark as consumed BEFORE issuing tokens (prevent race conditions)
        try await store.exchangeTokens.consume(exchangeToken: exchangeToken)

        // Get user from token
        let user = exchangeToken.user

        // Issue full JWT tokens
        return try await issue(for: user, sessionId: UUID(), origin: .exchange)
    }
}

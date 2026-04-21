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
        revokeExisting: Bool = true
    ) async throws -> AuthUser {
        if revokeExisting {
            try await revoke(for: user)
        }

        let accessToken = AccessToken(
            userId: try user.requiredIdAsString,
            expiresAt: .now.addingTimeInterval(configuration.accessToken.timeToLive),
            issuer: configuration.issuer,
            audience: nil,
            scope: nil
        )

        let opaqueToken = random.generateOpaqueToken()
        try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: opaqueToken),
            expiresAt: .now.addingTimeInterval(configuration.refreshToken.timeToLive)
        )

        return AuthUser(
            accessToken: try await request.jwt.sign(accessToken),
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

        let user = refreshToken.user

        let opaqueToken = random.generateOpaqueToken()
        try await store.tokens.createRefreshToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: opaqueToken),
            expiresAt: .now.addingTimeInterval(configuration.refreshToken.timeToLive),
            replacing: refreshToken
        )

        let accessToken = AccessToken(
            userId: try user.requiredIdAsString,
            expiresAt: .now.addingTimeInterval(configuration.accessToken.timeToLive),
            issuer: configuration.issuer,
            audience: nil,
            scope: nil
        )

        return AuthUser(
            accessToken: try await request.jwt.sign(accessToken),
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
        try await store.tokens.revokeRefreshToken(for: user)
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

        // Authenticate user in session (if sessions enabled)
        request.passage.login(user)

        // Issue full JWT tokens
        return try await issue(for: user)
    }
}

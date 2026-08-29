public import Foundation
import Vapor

public struct PassageContext: Sendable {
    let request: Request

    public var user: any User {
        get throws {
            try request.auth.require(request.store.users.userType)
        }
    }

    public var hasUser: Bool {
        request.auth.has(request.store.users.userType)
    }
}

// MARK: - Vapor Authentication

extension PassageContext {

    public func login(
        _ user: any User,
        origin: CredentialIssuance.Origin,
        via transport: Passage.Transport,
        sessionId: UUID = UUID(),
    ) async throws -> AuthUser? {
        switch transport {
        case .browser:
            guard request.configuration.sessions.enabled else {
                throw PassageError.sessionsDisabled
            }

            let request = self.request
            let hooks = request.hooks.account

            let issuance = try await request.store.transaction { store in
                let issuance = CredentialIssuance(
                    kind: .browser,
                    origin: origin,
                    user: user,
                    sessionId: sessionId,
                    store: store
                )

                try await hooks?.willIssueCredential(issuance, on: request)

                return issuance
            }

            request.auth.login(user)
            request.session.authenticate(user)
            request.session.sessionId = issuance.sessionId

            await hooks?.didIssueCredential(issuance, on: request)
            return nil

        case .bearer:
            request.auth.login(user)
            return try await request.tokens.issue(for: user, sessionId: sessionId, origin: origin)
        }
    }

    func logout() {
        request.auth.logout(request.store.users.userType)
        if request.configuration.sessions.enabled {
            request.session.unauthenticate(request.store.users.userType)
            request.session.sessionId = nil
        }
    }
}

// MARK: - Session Revocation

public extension PassageContext {

    func revoke(sessionId: UUID) async throws {
        try await request.tokens.revoke(sessionId: sessionId)
    }

}

// MARK: - Session Id Storage

extension PassageContext {

    struct BearerSessionIdKey: StorageKey {
        typealias Value = UUID
    }

    public var sessionId: UUID? {
        if let sessionId = request.storage[BearerSessionIdKey.self] {
            return sessionId
        }
        guard request.configuration.sessions.enabled, request.hasSession else {
            return nil
        }
        return request.session.sessionId
    }
}

// MARK: - Expose Passage Features

public extension PassageContext {

    var verification: Passage.Verification {
        request.verification
    }

    var passwordless: Passage.Passwordless {
        request.passwordless
    }
}

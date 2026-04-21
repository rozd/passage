import Foundation
import JWT
import Vapor

// MARK: - Linking State

extension Passage.Linking.ManualLinking {

    /// State preserved during multi-step OAuth account linking flow
    struct LinkingState: Codable, Sendable {

        struct Candidate: Codable, Sendable {
            let userId: String
            let email: String?
            let phone: String?
            let hasPassword: Bool
            let isEmailVerified: Bool
            let isPhoneVerified: Bool
        }

        let federatedIdentifier: Identifier
        let candidates: [Candidate]
        let provider: FederatedProvider.Name
        let createdAt: Date
        let expiresAt: Date

        var selectedUserId: String?
        var sentEmailCode: String?
        var sentPhoneCode: String?

        var isExpired: Bool { Date() > expiresAt }

        init(
            federatedIdentifier: Identifier,
            candidates: [Candidate],
            provider: FederatedProvider.Name,
            ttl: TimeInterval
        ) {
            self.federatedIdentifier = federatedIdentifier
            self.candidates = candidates
            self.provider = provider
            self.createdAt = Date()
            self.expiresAt = Date().addingTimeInterval(ttl)
        }

        func withSelectedUser(_ userId: String) -> LinkingState {
            var copy = self
            copy.selectedUserId = userId
            return copy
        }

        func withEmailCode(_ code: String) -> LinkingState {
            var copy = self
            copy.sentEmailCode = code
            return copy
        }

        func withPhoneCode(_ code: String) -> LinkingState {
            var copy = self
            copy.sentPhoneCode = code
            return copy
        }
    }

}

// MARK: - Linking State Storage

extension Passage.Linking.ManualLinking {

    /// Storage abstraction - session vs signed cookie based on configuration
    struct LinkingStateStorage: Sendable {

        let request: Request
        let config: Passage.Configuration

        private let sessionKey = "passage_account_linking_state"
        private let cookieName = "passage_account_linking"

        // MARK: - Public API

        func save(_ state: LinkingState) async throws {
            if config.sessions.enabled {
                try saveToSession(state)
            } else {
                try await saveToCookie(state)
            }
        }

        func load() async throws -> LinkingState? {
            if config.sessions.enabled {
                return try loadFromSession()
            } else {
                return try await loadFromCookie()
            }
        }

        func clear() {
            if config.sessions.enabled {
                request.session.data[sessionKey] = nil
            } else {
                // Clear cookie by setting expired value
                var cookie = HTTPCookies.Value(string: "")
                cookie.expires = Date(timeIntervalSince1970: 0)
                cookie.path = "/"
                cookie.isHTTPOnly = true
                cookie.sameSite = .lax
                request.cookies[cookieName] = cookie
            }
        }

        // MARK: Session Storage

        private func saveToSession(_ state: LinkingState) throws {
            let data = try JSONEncoder().encode(state)
            request.session.data[sessionKey] = String(data: data, encoding: .utf8)
        }

        private func loadFromSession() throws -> LinkingState? {
            guard let jsonString = request.session.data[sessionKey],
                  let data = jsonString.data(using: .utf8) else {
                return nil
            }
            return try JSONDecoder().decode(LinkingState.self, from: data)
        }

        // MARK: Cookie Storage (Signed JWT)

        private func saveToCookie(_ state: LinkingState) async throws {
            let jwt = try await createSignedJWT(state)
            request.cookies[cookieName] = HTTPCookies.Value(
                string: jwt,
                expires: state.expiresAt,
                maxAge: nil,
                domain: nil,
                path: "/",
                isSecure: request.application.environment != .development,
                isHTTPOnly: true,
                sameSite: .lax
            )
        }

        private func loadFromCookie() async throws -> LinkingState? {
            guard let jwt = request.cookies[cookieName]?.string, !jwt.isEmpty else {
                return nil
            }
            return try await verifyAndDecodeJWT(jwt)
        }

        private func createSignedJWT(_ state: LinkingState) async throws -> String {
            let stateData = try JSONEncoder().encode(state)
            let claims = LinkingStateClaims(
                data: stateData.base64EncodedString(),
                exp: ExpirationClaim(value: state.expiresAt)
            )

            return try await request.jwt.sign(claims)
        }

        private func verifyAndDecodeJWT(_ jwt: String) async throws -> LinkingState {
            let claims = try await request.jwt.verify(jwt, as: LinkingStateClaims.self)
            guard let stateData = Data(base64Encoded: claims.data) else {
                throw Abort(.badRequest, reason: "Invalid linking state")
            }
            return try JSONDecoder().decode(LinkingState.self, from: stateData)
        }
    }
}

// MARK: - JWT Claims

extension Passage.Linking.ManualLinking {

    struct LinkingStateClaims: JWTPayload, Sendable {
        let data: String
        let exp: ExpirationClaim

        func verify(using algorithm: some JWTAlgorithm) async throws {
            try exp.verifyNotExpired()
        }
    }

}

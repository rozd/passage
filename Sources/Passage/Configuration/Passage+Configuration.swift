public import Foundation
import Vapor

// MARK: - Passage Configuration

extension Passage {

    public struct Configuration: Sendable {
        let origin: URL
        let routes: Routes
        let tokens: Tokens
        let sessions: Sessions
        let jwt: JWT
        let passwordPolicy: PasswordPolicy
        let passwordless: Passwordless
        let verification: Verification
        let restoration: Restoration
        let federatedLogin: FederatedLogin
        let passkey: Passkey
        let throttle: Passage.Configuration.Throttle
        let views: Views

        public init(
            origin: URL,
            routes: Routes = .init(),
            tokens: Tokens = .init(),
            sessions: Sessions = .init(),
            jwt: JWT? = nil,
            passwordPolicy: PasswordPolicy = .relaxed(),
            passwordless: Passwordless = .init(),
            verification: Verification = .init(),
            restoration: Restoration = .init(),
            federatedLogin: FederatedLogin = .init(routes: .init(), providers: []),
            passkey: Passkey = .init(),
            throttle: Passage.Configuration.Throttle = .init(),
            views: Views = .init(),
        ) throws {
            self.origin = origin
            self.routes = routes
            self.tokens = tokens
            self.sessions = sessions
            self.jwt = try jwt ?? JWT(jwks: try .fileFromEnvironment())
            self.passwordPolicy = passwordPolicy
            self.passwordless = passwordless
            self.verification = verification
            self.restoration = restoration
            self.federatedLogin = federatedLogin
            self.passkey = passkey
            self.throttle = throttle
            self.views = views
        }
    }
}

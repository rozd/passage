import Vapor

// MARK: - Federated Login

public extension Passage {

    struct FederatedLogin: Sendable {
        let request: Request
    }

}

// MARK: - Service Accessors

extension Passage.FederatedLogin {

    var store: any Passage.Store {
        request.store
    }

    var tokens: Passage.Tokens {
        request.tokens
    }

    var configuration: Passage.Configuration.FederatedLogin {
        request.configuration.federatedLogin
    }

}

extension Request {

    var federated: Passage.FederatedLogin {
        .init(request: self)
    }

}

// MARK: - Sign In

extension Passage.FederatedLogin {

    /// Login with federated identity, with support for manual account linking
    /// Returns Response (redirect to linking form or to configured redirect location)
    func login(
        identity: FederatedIdentity
    ) async throws -> Response {
        // Check if already has this federated identifier
        if let user = try await store.users.find(byIdentifier: identity.identifier) {
            return try await completeLogin(for: user)
        }

        let linkingResult: Passage.Linking.Result
        switch configuration.accountLinking.resolution {
        case .automatic(let allowedIdentifiers, let resolution):
            linkingResult = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: allowedIdentifiers,
                onAmbiguousMatch: resolution,
            )
            break
        case .manual(let allowedIdentifiers):
            linkingResult = try await request.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: allowedIdentifiers,
            )
        case .disabled:
            linkingResult = .skipped
            break
        }

        switch linkingResult {
        case .complete(let user):
            return try await completeLogin(for: user)
        case .skipped:
            let user = try await store.users.create(
                identifier: identity.identifier,
                with: nil
            )
            return try await completeLogin(for: user)
        case .conflict(_):
            // TODO: let developers know about conflicts in redirection response
            let user = try await store.users.create(
                identifier: identity.identifier,
                with: nil
            )
            return try await completeLogin(for: user)
        case .initiated:
            return request.redirect(to: "/" + (request.configuration.routes.group + configuration.linkAccountSelectPath).string)
        }
    }

    /// Complete login by issuing tokens and redirecting
    private func completeLogin(for user: any User) async throws -> Response {
        // Session authentication (for SSR)
        request.passage.login(user)

        // Build redirect URL with generated exchange code for API clients
        let redirectURL = buildRedirectURL(
            base: configuration.redirectLocation,
            code: try await request.tokens.createExchangeCode(for: user)
        )

        return request.redirect(to: redirectURL)
    }

    /// Build redirect URL with exchange code as query parameter
    private func buildRedirectURL(base: String, code: String) -> String {
        if base.contains("?") {
            return "\(base)&code=\(code)"
        } else {
            return "\(base)?code=\(code)"
        }
    }

}

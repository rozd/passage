import Vapor

// MARK: - Linking Namespace

extension Passage {

    struct Linking: Sendable {
        let request: Request
    }

}

// MARK: - Request Extension

extension Request {

    var linking: Passage.Linking {
        .init(request: self)
    }

}

// MARK: - Automatic Linking Accessor

extension Passage.Linking {

    var automatic: AutomaticLinking {
        .init(linking: self)
    }

}

// MARK: - Manual Linking Accessor

extension Passage.Linking {

    var manual: ManualLinking {
        .init(linking: self)
    }

}

// MARK: - Service Accessors

extension Passage.Linking {

    var config: Passage.Configuration.FederatedLogin.AccountLinking {
        request.configuration.federatedLogin.accountLinking
    }

    var store: any Passage.Store {
        request.store
    }

    var random: any Passage.RandomGenerator {
        request.random
    }

}


// MARK: - Linking Helper

extension Passage.Linking {

    func link(
        federatedIdentifier identifier: Identifier,
        to user: any User,
    ) async throws {
        let existing = try await store.users.find(byIdentifier: identifier)
        if let existing = existing {
            guard existing.equals(to: user) else {
                throw Abort(.conflict, reason: "This provider account is already linked to another user")
            }
        } else {
            try await store.users.addIdentifier(identifier, to: user, with: nil)
        }
    }

}

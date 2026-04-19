import Foundation
import Vapor

extension Passage {

    public struct Passkey: Sendable {
        let request: Request
        let config: Passage.Configuration.Passkey
    }
}

// MARK: - Service Accessors

extension Request {
    var passkey: Passage.Passkey {
        .init(
            request: self,
            config: configuration.passkey,
        )
    }
}

extension Passage.Passkey {

    var service: (any Passage.PasskeyService)? {
        request.services.passkey
    }

}

// MARK: - Registration Ceremony

extension Passage.Passkey {

    // MARK: Signup — public, form-driven

    func beginSignup(
        form: any PasskeySignupForm
    ) async throws -> any AsyncResponseEncodable & Sendable {
        guard let service else {
            throw PassageError.passkeyServiceNotAvailable
        }
        guard let challenges = request.store.passkeyChallenges else {
            throw PassageError.passkeyNotConfigured
        }

        let identifier = try form.asIdentifier()
        let existing = try await request.store.users.find(byIdentifier: identifier)

        let userEntity: PublicKeyCredentialUserEntity = existing.map {
            .init(for: $0, displayName: form.displayName)
        } ?? .init(for: identifier, displayName: form.displayName)

        let result = try await service.beginRegistration(
            with: userEntity,
            policy: config.policy,
            challengeTTL: config.challengeTTL,
        )

        let user: any User
        if let existing {
            user = existing
        } else {
            user = try await request.store.users.create(identifier: identifier, with: nil)
        }

        try await challenges.createPasskeyChallenge(for: user, from: result.challenge)
        return result.body
    }

    func finishSignup(
        rawBody: Data
    ) async throws -> any StoredPasskeyCredential {
        return try await finishRegistrationCore(rawBody: rawBody, authenticatedUser: nil)
    }

    // MARK: Register — authenticated user adding a passkey

    func beginRegistration(
        request body: PasskeyRegisterRequest?
    ) async throws -> any AsyncResponseEncodable & Sendable {
        let user = try request.passage.user
        let displayName = body?.displayName ?? user.username ?? user.email ?? user.phone ?? "Passkey"
        let userEntity = PublicKeyCredentialUserEntity(for: user, displayName: displayName)
        return try await beginRegistrationCore(for: user, userEntity: userEntity)
    }

    func finishRegistration(
        rawBody: Data
    ) async throws -> any StoredPasskeyCredential {
        let authUser = try request.passage.user
        return try await finishRegistrationCore(rawBody: rawBody, authenticatedUser: authUser)
    }

    // MARK: Shared core

    private func beginRegistrationCore(
        for user: any User,
        userEntity: PublicKeyCredentialUserEntity,
    ) async throws -> any AsyncResponseEncodable & Sendable {
        guard let service else {
            throw PassageError.passkeyServiceNotAvailable
        }
        guard let challenges = request.store.passkeyChallenges else {
            throw PassageError.passkeyNotConfigured
        }

        let result = try await service.beginRegistration(
            with: userEntity,
            policy: config.policy,
            challengeTTL: config.challengeTTL,
        )

        try await challenges.createPasskeyChallenge(for: user, from: result.challenge)

        return result.body
    }

    private func finishRegistrationCore(
        rawBody: Data,
        authenticatedUser: (any User)?,
    ) async throws -> any StoredPasskeyCredential {
        guard let service else {
            throw PassageError.passkeyServiceNotAvailable
        }
        guard
            let credentials = request.store.passkeyCredentials,
            let challenges = request.store.passkeyChallenges
        else {
            throw PassageError.passkeyNotConfigured
        }

        let result = try await service.finishRegistration(
            rawBody: rawBody,
            policy: config.policy,
            lookupChallenge: { bytes in
                guard
                    let stored = try await challenges.find(passkeyChallengeMatching: bytes),
                    stored.kind == .registration,
                    stored.isValid,
                    stored.user != nil
                else {
                    return nil
                }
                return stored
            },
            confirmUnused: { id in
                try await credentials.find(byCredentialID: id) == nil
            },
        )

        guard let user = result.matchedChallenge.user else {
            throw AuthenticationError.invalidPasskeyChallenge
        }

        // Defense-in-depth: if the finish happened on the authenticated path,
        // the session user must match the user the challenge was issued for.
        if let authenticatedUser, !authenticatedUser.equals(to: user) {
            throw AuthenticationError.invalidPasskeyChallenge
        }

        let stored = try await credentials.createPasskeyCredential(for: user, from: result.credential)
        try await challenges.consume(passkeyChallenge: result.matchedChallenge)

        return stored
    }

}

// MARK: - Authentication Ceremony

extension Passage.Passkey {

    func beginAuthentication() async throws -> any AsyncResponseEncodable & Sendable {
        guard let service else {
            throw PassageError.passkeyServiceNotAvailable
        }
        guard let challenges = request.store.passkeyChallenges else {
            throw PassageError.passkeyNotConfigured
        }
        guard config.policy.allowDiscoverableLogin else {
            throw AuthenticationError.discoverableLoginDisabled
        }

        let result = try await service.beginAuthentication(
            allowCredentials: nil,
            policy: config.policy,
            challengeTTL: config.challengeTTL,
        )

        try await challenges.createPasskeyChallenge(for: nil, from: result.challenge)

        return result.body
    }

    func finishAuthentication(
        rawBody: Data
    ) async throws -> (user: any User, code: String) {
        guard let service else {
            throw PassageError.passkeyServiceNotAvailable
        }
        guard
            let credentials = request.store.passkeyCredentials,
            let challenges = request.store.passkeyChallenges
        else {
            throw PassageError.passkeyNotConfigured
        }

        let result = try await service.finishAuthentication(
            rawBody: rawBody,
            policy: config.policy,
            lookupChallenge: { bytes in
                guard
                    let stored = try await challenges.find(passkeyChallengeMatching: bytes),
                    stored.kind == .authentication,
                    stored.isValid
                else {
                    return nil
                }
                return stored
            },
            lookupCredential: { id in
                try await credentials.find(byCredentialID: id)
            },
        )

        try await credentials.updatePasskeyCredentialAfterAuthentication(
            forCredentialID: result.matchedCredential.credentialID,
            newSignCount: result.newSignCount,
            isBackedUp: result.credentialBackedUp,
        )
        try await challenges.consume(passkeyChallenge: result.matchedChallenge)

        let user = result.matchedCredential.user
        request.passage.login(user)
        let code = try await request.tokens.createExchangeCode(for: user)
        return (user, code)
    }

}

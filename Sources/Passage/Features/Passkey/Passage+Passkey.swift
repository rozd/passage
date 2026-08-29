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

    // MARK: Guest Registration — unauthenticated user starting registration with an identifier

    func beginGuestRegistration(
        form: any PasskeyGuestRegistrationForm
    ) async throws -> any AsyncResponseEncodable & Sendable {
        guard let service else {
            throw PassageError.passkeyServiceNotAvailable
        }
        guard let challenges = request.store.passkeyChallenges else {
            throw PassageError.passkeyNotConfigured
        }

        let identifier = try form.asIdentifier()
        guard try await request.store.users.find(byIdentifier: identifier) == nil else {
            throw AuthenticationError.identifierAlreadyRegistered
        }

        let userEntity = PublicKeyCredentialUserEntity(for: identifier, displayName: form.displayName)

        try await request.hooks.passkey?.willBeginGuestRegistration(
            with: form, as: userEntity, on: request
        )

        let result = try await service.beginRegistration(
            with: userEntity,
            policy: config.policy,
            challengeTTL: config.challengeTTL,
        )

        try await challenges.createPasskeyChallenge(for: identifier, from: result.challenge)

        await request.hooks.passkey?.didBeginGuestRegistration(
            with: result, on: request
        )

        return result.body
    }

    // MARK: Register — authenticated user adding a passkey

    func beginRegistration(
        request body: PasskeyRegisterRequest?
    ) async throws -> any AsyncResponseEncodable & Sendable {
        guard let service else {
            throw PassageError.passkeyServiceNotAvailable
        }
        guard let challenges = request.store.passkeyChallenges else {
            throw PassageError.passkeyNotConfigured
        }

        let user = try request.passage.user

        let userEntity = PublicKeyCredentialUserEntity(
            for: user,
            displayName: body?.displayName ?? user.username ?? user.email ?? user.phone ?? "Passkey",
        )

        try await request.hooks.passkey?.willBeginRegistration(
            for: user, as: userEntity, on: request
        )

        let result = try await service.beginRegistration(
            with: userEntity,
            policy: config.policy,
            challengeTTL: config.challengeTTL,
        )

        try await challenges.createPasskeyChallenge(for: user, from: result.challenge)

        await request.hooks.passkey?.didBeginRegistration(
            with: result, for: user, on: request
        )

        return result.body
    }

    // MARK: Finish Registration — shared by both flows

    func finishRegistration(
        rawBody: Data
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
                    stored.user != nil || stored.identifier != nil
                else {
                    return nil
                }
                return stored
            },
            confirmUnused: { id in
                try await credentials.find(byCredentialID: id) == nil
            },
        )

        let user: any User
        if let bound = result.matchedChallenge.user {
            guard try request.passage.user.equals(to: bound) else {
                throw AuthenticationError.invalidPasskeyChallenge
            }
            try await request.hooks.passkey?.willFinishRegistration(
                for: bound, on: request
            )
            user = bound
        } else if let identifier = result.matchedChallenge.identifier {
            guard try await request.store.users.find(byIdentifier: identifier) == nil else {
                throw AuthenticationError.invalidPasskeyChallenge
            }
            try await request.hooks.passkey?.willFinishGuestRegistration(
                with: identifier, on: request
            )
            user = try await request.store.users.create(identifier: identifier, with: nil)
        } else {
            throw AuthenticationError.invalidPasskeyChallenge
        }

        let stored = try await credentials.createPasskeyCredential(for: user, from: result.credential)
        try await challenges.consume(passkeyChallenge: result.matchedChallenge)

        if result.matchedChallenge.user == nil {
            await request.hooks.passkey?.didFinishGuestRegistration(
                with: stored, for: user, on: request
            )
        } else {
            await request.hooks.passkey?.didFinishRegistration(
                with: stored, for: user, on: request
            )
        }

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

        try await request.hooks.passkey?.willBeginAuthentication(on: request)

        let result = try await service.beginAuthentication(
            allowCredentials: nil,
            policy: config.policy,
            challengeTTL: config.challengeTTL,
        )

        try await challenges.createPasskeyChallenge(from: result.challenge)

        await request.hooks.passkey?.didBeginAuthentication(
            with: result, on: request
        )

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

        let user = result.matchedCredential.user
        try await request.hooks.passkey?.willFinishAuthentication(
            with: result.matchedCredential, for: user, on: request
        )

        try await credentials.updatePasskeyCredentialAfterAuthentication(
            forCredentialID: result.matchedCredential.credentialID,
            newSignCount: result.newSignCount,
            isBackedUp: result.credentialBackedUp,
        )
        try await challenges.consume(passkeyChallenge: result.matchedChallenge)

        if request.configuration.sessions.enabled {
            _ = try await request.passage.login(user, origin: .passkey, via: .browser)
        }
        let code = try await request.tokens.createExchangeCode(for: user)

        await request.hooks.passkey?.didFinishAuthentication(
            with: result.matchedCredential, for: user, code: code, on: request
        )

        return (user, code)
    }

}

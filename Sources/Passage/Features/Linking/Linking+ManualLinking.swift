import Vapor

// MARK: - Manual Linking

extension Passage.Linking {

    struct ManualLinking: Sendable {
        let linking: Passage.Linking
    }

}

// MARK: - Service Accessors

extension Passage.Linking.ManualLinking {

    var request: Request {
        linking.request
    }

    var store: any Passage.Store {
        linking.store
    }

    var config: Passage.Configuration.FederatedLogin.AccountLinking {
        linking.config
    }

    var storage: LinkingStateStorage {
        LinkingStateStorage(request: request, config: request.configuration)
    }
}

// MARK: - Linking Flow

extension Passage.Linking.ManualLinking {

    func initiate(
        for identity: FederatedIdentity,
        withAllowedIdentifiers kinds: [Identifier.Kind]
    ) async throws -> Passage.Linking.Result {

        let candidates = try await findLinkingCandidates(
            for: identity,
            withAllowedIdentifiers: kinds
        )

        guard candidates.count > 0 else {
            return .skipped
        }

        guard request.configuration.views.linkAccountSelect != nil &&
                request.configuration.views.linkAccountVerify != nil else {
            return .conflict(candidates: candidates.map { $0.userId } )
        }


        try await createLinkingState(
            identity: identity,
            candidates: candidates,
            provider: identity.provider
        )

        return .initiated
    }

    func advance(withSelectedUserId userId: String) async throws {
        let state = try await loadLinkingState()

        guard let candidate = state.candidates.first(where: { $0.userId == userId }) else {
            throw Abort(.badRequest, reason: "Invalid user selection")
        }

        // Update state with selection
        var updatedState = state.withSelectedUser(candidate.userId)

        if !candidate.hasPassword {
            if candidate.isEmailVerified, let email = candidate.email {
                let code = try await request.verification.sendEmailCode(toEmail: email)
                updatedState = updatedState.withEmailCode(code)
            } else if candidate.isPhoneVerified, let phone = candidate.phone {
                let code = try await request.verification.sendPhoneCode(toPhone: phone)
                updatedState = updatedState.withPhoneCode(code)
            } else {
                throw Abort(.badRequest, reason: "No verification method available for selected user")
            }
        }

        try await request.linking.manual.updateLinkingState(updatedState)
    }

    func complete(
        password: String?,
        verificationCode: String?
    ) async throws -> any User {
        let state = try await loadLinkingState()

        guard let selectedUserId = state.selectedUserId else {
            throw Abort(.badRequest, reason: "No user selected")
        }

        guard state.candidates.contains(where: { $0.userId == selectedUserId }) else {
            throw Abort(.badRequest, reason: "Invalid user selection")
        }

        guard let user = try await request.store.users.find(byId: selectedUserId) else {
            throw Abort(.notFound, reason: "User not found")
        }

        if let password = password, !password.isEmpty {
            try await complete(for: user, trackingIn: state, withPassword: password)
        } else if let code = verificationCode {
            try await complete(for: user, trackingIn: state, withVerificationCode: code)
        } else {
            throw Abort(.badRequest, reason: "No verification method provided")
        }

        clearLinkingState()

        request.passage.login(user)
        
        return user
    }

    private func complete(
        for user: any User,
        trackingIn state: LinkingState,
        withPassword password: String,
    ) async throws {

        guard let passwordHash = user.passwordHash else {
            throw AuthenticationError.passwordIsNotSet
        }

        let isValid = try await request.password.async.verify(
            password,
            created: passwordHash
        )

        guard isValid else {
            throw Abort(.unauthorized, reason: "Invalid password")
        }

        try await linking.link(
            federatedIdentifier: state.federatedIdentifier,
            to: user
        )
    }

    private func complete(
        for user: any User,
        trackingIn state: LinkingState,
        withVerificationCode code: String,
    ) async throws {

        guard let expectedCode = state.sentEmailCode ?? state.sentPhoneCode else {
            throw Abort(.badRequest, reason: "No verification code sent")
        }

        guard code.uppercased() == expectedCode.uppercased() else {
            throw AuthenticationError.invalidVerificationCode
        }

        try await linking.link(
            federatedIdentifier: state.federatedIdentifier,
            to: user
        )
    }
}


// MARK: - State Management

extension Passage.Linking.ManualLinking {

    func createLinkingState(
        identity: FederatedIdentity,
        candidates: [LinkingState.Candidate],
        provider: FederatedProvider.Name,
    ) async throws {
        let state = LinkingState(
            federatedIdentifier: identity.identifier,
            candidates: candidates,
            provider: provider,
            ttl: config.stateExpiration
        )
        try await storage.save(state)
    }

    func loadLinkingState() async throws -> LinkingState {
        guard let state = try await storage.load() else {
            throw Abort(.badRequest, reason: "No linking session found")
        }
        guard !state.isExpired else {
            storage.clear()
            throw Abort(.badRequest, reason: "Linking session expired")
        }
        return state
    }

    private func updateLinkingState(_ state: LinkingState) async throws {
        try await storage.save(state)
    }

    private func clearLinkingState() {
        storage.clear()
    }

}

// MARK: - Candidate Detection Helpers

extension Passage.Linking.ManualLinking {

    private func findLinkingCandidates(
        for identity: FederatedIdentity,
        withAllowedIdentifiers kinds: [Identifier.Kind]
    ) async throws -> [LinkingState.Candidate] {
        var candidates: [LinkingState.Candidate] = []

        for kind in kinds {
            switch kind {
            case .email:
                for email in identity.verifiedEmails {
                    guard let user = try await store.users.find(byIdentifier: .email(email)) else {
                        continue
                    }
                    guard user.passwordHash != nil || user.isEmailVerified else {
                        // Only include if user can be verified (has password OR verified email)
                        continue
                    }
                    candidates.append(
                        LinkingState.Candidate(
                            userId: try user.requiredIdAsString,
                            email: user.email,
                            phone: nil,
                            hasPassword: user.passwordHash != nil,
                            isEmailVerified: user.isEmailVerified,
                            isPhoneVerified: user.isPhoneVerified,
                        )
                    )
                }
                break
            case .phone:
                for phone in identity.verifiedPhoneNumbers {
                    guard let user = try await store.users.find(byIdentifier: .phone(phone)) else {
                        continue
                    }
                    guard user.passwordHash != nil || user.isPhoneVerified else {
                        // Only include if user can be verified (has password OR verified phone)
                        continue
                    }
                    candidates.append(
                        LinkingState.Candidate(
                            userId: try user.requiredIdAsString,
                            email: nil,
                            phone: user.phone,
                            hasPassword: user.passwordHash != nil,
                            isEmailVerified: user.isEmailVerified,
                            isPhoneVerified: user.isPhoneVerified,
                        )
                    )
                }
                break
            case .username, .federated:
                break
            }
        }

        return candidates
    }

}

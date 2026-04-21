import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite("Manual Linking Tests", .tags(.integration, .federatedLogin))
struct ManualLinkingTests {

    // MARK: - Configuration Helper

    /// Configures a test Vapor application with Passage and manual linking enabled
    @Sendable private func configureWithManualLinking(
        _ app: Application,
        allowedIdentifiers: [Identifier.Kind] = [.email],
        withViews: Bool = true
    ) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        let store = Passage.OnlyForTest.InMemoryStore()
        let emailDelivery = Passage.OnlyForTest.MockEmailDelivery()
        let phoneDelivery = Passage.OnlyForTest.MockPhoneDelivery()

        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: emailDelivery,
            phoneDelivery: phoneDelivery,
            federatedLogin: nil
        )

        // Configure views if needed (manual linking requires views for full flow)
        let views: Passage.Configuration.Views
        if withViews {
            let theme = Passage.Views.Theme(colors: .defaultLight)
            views = .init(
                linkAccountSelect: .init(style: .minimalism, theme: theme),
                linkAccountVerify: .init(style: .minimalism, theme: theme)
            )
        } else {
            views = .init()
        }

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: "{\"keys\":[]}")),
            verification: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: false
            ),
            restoration: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: false
            ),
            federatedLogin: .init(
                providers: [],
                accountLinking: .init(
                    resolution: .manual(matchBy: allowedIdentifiers),
                    stateExpiration: 600
                ),
                redirectLocation: "/dashboard"
            ),
            views: views
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )
    }

    /// Creates a test user with the given identifier
    @Sendable private func createTestUser(
        app: Application,
        email: String? = nil,
        phone: String? = nil,
        password: String? = nil,
        isEmailVerified: Bool = false,
        isPhoneVerified: Bool = false
    ) async throws -> any User {
        let store = app.passage.storage.services.store

        let identifier: Identifier
        if let email = email {
            identifier = .email(email)
        } else if let phone = phone {
            identifier = .phone(phone)
        } else {
            throw PassageError.unexpected(message: "At least one identifier must be provided")
        }

        var credential: Credential? = nil
        if let password = password {
            let passwordHash = try await app.password.async.hash(password)
            credential = .password(passwordHash)
        }

        let user = try await store.users.create(identifier: identifier, with: credential)

        if isEmailVerified {
            try await store.users.markEmailVerified(for: user)
        }
        if isPhoneVerified {
            try await store.users.markPhoneVerified(for: user)
        }

        return user
    }

    // MARK: - Initiate Tests

    @Test("Manual linking initiate returns skipped when no candidates found")
    func initiateReturnsSkippedWhenNoCandidates() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app)
        }) { app in
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "new-user"),
                provider: .google,
                verifiedEmails: ["nonexistent@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: [.email]
            )

            if case .skipped = result {
                #expect(Bool(true))
            } else {
                Issue.record("Expected .skipped result")
            }
        }
    }

    @Test("Manual linking initiate returns conflict when views not configured")
    func initiateReturnsConflictWhenNoViews() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: false)
        }) { app in
            // Create user that can be a candidate
            let user = try await createTestUser(
                app: app,
                email: "candidate@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "link-attempt"),
                provider: .google,
                verifiedEmails: ["candidate@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: [.email]
            )

            // Without views, should return conflict with candidate IDs
            if case .conflict(let candidates) = result {
                #expect(candidates.count == 1)
                #expect(candidates.contains(user.id!.description))
            } else {
                Issue.record("Expected .conflict result when views not configured")
            }
        }
    }

    @Test("Manual linking initiate returns initiated when candidates found and views configured")
    func initiateReturnsInitiatedWhenCandidatesAndViews() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            // Create user that can be a candidate
            _ = try await createTestUser(
                app: app,
                email: "linkable@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "link-with-views"),
                provider: .google,
                verifiedEmails: ["linkable@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: [.email]
            )

            if case .initiated = result {
                #expect(Bool(true))
            } else {
                Issue.record("Expected .initiated result")
            }
        }
    }

    // MARK: - Candidate Detection Tests

    @Test("Manual linking only includes users who can be verified")
    func onlyIncludesVerifiableUsers() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            // User 1: Has password - should be included
            _ = try await createTestUser(
                app: app,
                email: "with-password@example.com",
                password: "password123",
                isEmailVerified: false
            )

            // User 2: Has verified email - should be included
            _ = try await createTestUser(
                app: app,
                email: "verified-email@example.com",
                isEmailVerified: true
            )

            // User 3: No password, no verified email - should NOT be included
            _ = try await createTestUser(
                app: app,
                email: "unverifiable@example.com",
                isEmailVerified: false
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "multi"),
                provider: .google,
                verifiedEmails: [
                    "with-password@example.com",
                    "verified-email@example.com",
                    "unverifiable@example.com"
                ],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: [.email]
            )

            // Should be initiated (candidates found)
            if case .initiated = result {
                // State should have been created with 2 candidates (not 3)
                let state = try await request.linking.manual.loadLinkingState()
                #expect(state.candidates.count == 2)

                let candidateEmails = state.candidates.compactMap { $0.email }
                #expect(candidateEmails.contains("with-password@example.com"))
                #expect(candidateEmails.contains("verified-email@example.com"))
                #expect(!candidateEmails.contains("unverifiable@example.com"))
            } else {
                Issue.record("Expected .initiated result")
            }
        }
    }

    // MARK: - Advance Flow Tests

    @Test("Advance throws error for invalid user selection")
    func advanceThrowsForInvalidSelection() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            // Create a candidate user
            _ = try await createTestUser(
                app: app,
                email: "candidate@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "advance-test"),
                provider: .google,
                verifiedEmails: ["candidate@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())

            // Initiate linking
            _ = try await request.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: [.email]
            )

            // Try to advance with invalid user ID
            await #expect(throws: (any Error).self) {
                try await request.linking.manual.advance(withSelectedUserId: "invalid-user-id")
            }
        }
    }

    // MARK: - Complete Flow Tests

    @Test("Complete throws error when no user selected")
    func completeThrowsWhenNoUserSelected() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            _ = try await createTestUser(
                app: app,
                email: "candidate@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "complete-test"),
                provider: .google,
                verifiedEmails: ["candidate@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())

            // Initiate but don't advance (no user selected)
            _ = try await request.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: [.email]
            )

            // Try to complete without selecting a user
            await #expect(throws: (any Error).self) {
                _ = try await request.linking.manual.complete(
                    password: "password123",
                    verificationCode: nil
                )
            }
        }
    }

    @Test("Complete throws error with no verification method provided")
    func completeThrowsWithNoVerificationMethod() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            let user = try await createTestUser(
                app: app,
                email: "complete-user@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "verify-test"),
                provider: .google,
                verifiedEmails: ["complete-user@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())

            // Initiate
            _ = try await request.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: [.email]
            )

            // Advance with valid user
            try await request.linking.manual.advance(withSelectedUserId: user.id!.description)

            // Try to complete without password or code
            await #expect(throws: (any Error).self) {
                _ = try await request.linking.manual.complete(
                    password: nil,
                    verificationCode: nil
                )
            }
        }
    }

    // MARK: - State Management Tests

    @Test("Load linking state throws when no session exists")
    func loadStateThrowsWhenNoSession() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app)
        }) { app in
            let request = Request(application: app, on: app.eventLoopGroup.any())

            await #expect(throws: (any Error).self) {
                _ = try await request.linking.manual.loadLinkingState()
            }
        }
    }

    // MARK: - Password Verification Tests

    @Test("Complete with correct password succeeds")
    func completeWithCorrectPasswordSucceeds() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            let user = try await createTestUser(
                app: app,
                email: "password-user@example.com",
                password: "correct-password",
                isEmailVerified: true
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "password-test"),
                provider: .google,
                verifiedEmails: ["password-user@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())

            // Initiate
            _ = try await request.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: [.email]
            )

            // Advance
            try await request.linking.manual.advance(withSelectedUserId: user.id!.description)

            // Complete with correct password
            let linkedUser = try await request.linking.manual.complete(
                password: "correct-password",
                verificationCode: nil
            )

            #expect(linkedUser.email == "password-user@example.com")
        }
    }

    @Test("Complete with wrong password fails")
    func completeWithWrongPasswordFails() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            let user = try await createTestUser(
                app: app,
                email: "wrong-password@example.com",
                password: "correct-password",
                isEmailVerified: true
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "wrong-pw-test"),
                provider: .google,
                verifiedEmails: ["wrong-password@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())

            // Initiate and advance
            _ = try await request.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: [.email]
            )
            try await request.linking.manual.advance(withSelectedUserId: user.id!.description)

            // Complete with wrong password
            await #expect(throws: (any Error).self) {
                _ = try await request.linking.manual.complete(
                    password: "wrong-password",
                    verificationCode: nil
                )
            }
        }
    }
}

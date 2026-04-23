import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration, .federatedLogin))
struct `Automatic Linking Tests` {

    // MARK: - Configuration Helper

    /// Configures a test Vapor application with Passage and automatic linking enabled
    @Sendable private func configureWithAutomaticLinking(
        _ app: Application,
        allowedIdentifiers: [Identifier.Kind] = [.email]
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
                accountLinking: .init(resolution: .automatic(matchBy: allowedIdentifiers, onAmbiguity: .requestManualSelection)),
                redirectLocation: "/dashboard"
            )
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

    // MARK: - Skipped (No Match) Tests

    @Test
    func `Automatic linking returns skipped when no matching users exist`() async throws {
        try await withApp(configure: { app in
            try await configureWithAutomaticLinking(app)
        }) { app in
            // Create federated identity with email that doesn't exist in system
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "new-user"),
                provider: .google,
                verifiedEmails: ["nonexistent@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            // Perform automatic linking
            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: [.email],
                onAmbiguousMatch: .requestManualSelection
            )

            if case .skipped = result {
                #expect(Bool(true))
            } else {
                Issue.record("Expected .skipped result")
            }
        }
    }

    @Test
    func `Automatic linking returns skipped when matched user email is not verified`() async throws {
        try await withApp(configure: { app in
            try await configureWithAutomaticLinking(app)
        }) { app in
            // Create user with unverified email
            _ = try await createTestUser(
                app: app,
                email: "unverified@example.com",
                isEmailVerified: false
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "link-attempt"),
                provider: .google,
                verifiedEmails: ["unverified@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: [.email],
                onAmbiguousMatch: .requestManualSelection
            )

            // Should be skipped because user's email is not verified
            if case .skipped = result {
                #expect(Bool(true))
            } else {
                Issue.record("Expected .skipped result because user email is not verified")
            }
        }
    }

    // MARK: - Complete (Single Match) Tests

    @Test
    func `Automatic linking returns complete when single verified email matches`() async throws {
        try await withApp(configure: { app in
            try await configureWithAutomaticLinking(app)
        }) { app in
            // Create user with verified email
            let existingUser = try await createTestUser(
                app: app,
                email: "existing@example.com",
                isEmailVerified: true
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "link-success"),
                provider: .google,
                verifiedEmails: ["existing@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: [.email],
                onAmbiguousMatch: .requestManualSelection
            )

            if case .complete(let linkedUser) = result {
                #expect(linkedUser.email == "existing@example.com")
                #expect(linkedUser.id?.description == existingUser.id?.description)
            } else {
                Issue.record("Expected .complete result")
            }
        }
    }

    @Test
    func `Automatic linking returns complete when single verified phone matches`() async throws {
        try await withApp(configure: { app in
            try await configureWithAutomaticLinking(app, allowedIdentifiers: [.phone])
        }) { app in
            // Create user with verified phone
            let existingUser = try await createTestUser(
                app: app,
                phone: "+1234567890",
                isPhoneVerified: true
            )

            let identity = FederatedIdentity(
                identifier: .federated(.named("auth0"), userId: "phone-user"),
                provider: .named("auth0"),
                verifiedEmails: [],
                verifiedPhoneNumbers: ["+1234567890"],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: [.phone],
                onAmbiguousMatch: .requestManualSelection
            )

            if case .complete(let linkedUser) = result {
                #expect(linkedUser.phone == "+1234567890")
                #expect(linkedUser.id?.description == existingUser.id?.description)
            } else {
                Issue.record("Expected .complete result")
            }
        }
    }

    // MARK: - Conflict (Multiple Matches) Tests

    @Test
    func `Automatic linking returns conflict when multiple users match`() async throws {
        try await withApp(configure: { app in
            try await configureWithAutomaticLinking(app)
        }) { app in
            // Create two users with different verified emails
            let user1 = try await createTestUser(
                app: app,
                email: "user1@example.com",
                isEmailVerified: true
            )
            let user2 = try await createTestUser(
                app: app,
                email: "user2@example.com",
                isEmailVerified: true
            )

            // Federated identity has both emails
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "multi-email"),
                provider: .google,
                verifiedEmails: ["user1@example.com", "user2@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: [.email],
                onAmbiguousMatch: .notifyAndCreateNew,
            )

            if case .conflict(let candidates) = result {
                #expect(candidates.count == 2)
                #expect(candidates.contains(user1.id!.description))
                #expect(candidates.contains(user2.id!.description))
            } else {
                Issue.record("Expected .conflict result")
            }
        }
    }

    @Test
    func `Automatic linking returns skipped on ambiguous match with ignoreAndCreateNew resolution`() async throws {
        try await withApp(configure: { app in
            try await configureWithAutomaticLinking(app)
        }) { app in
            let user1 = try await createTestUser(app: app, email: "a@example.com", isEmailVerified: true)
            let user2 = try await createTestUser(app: app, email: "b@example.com", isEmailVerified: true)

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "multi-match"),
                provider: .google,
                verifiedEmails: [user1.email!, user2.email!],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: [.email],
                onAmbiguousMatch: .ignoreAndCreateNew
            )

            if case .skipped = result {
                #expect(Bool(true))
            } else {
                Issue.record("Expected .skipped when ignoreAndCreateNew resolves ambiguity")
            }
        }
    }

    // MARK: - Identifier Type Tests

    @Test
    func `Automatic linking only checks allowed identifier types`() async throws {
        try await withApp(configure: { app in
            // Only allow email linking
            try await configureWithAutomaticLinking(app, allowedIdentifiers: [.email])
        }) { app in
            // Create user with verified phone (not email)
            _ = try await createTestUser(
                app: app,
                phone: "+1234567890",
                isPhoneVerified: true
            )

            // Identity has matching phone but email is allowed only
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "phone-only"),
                provider: .google,
                verifiedEmails: [],
                verifiedPhoneNumbers: ["+1234567890"],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: [.email], // Only email allowed
                onAmbiguousMatch: .requestManualSelection,
            )

            // Should skip because phone is not in allowed identifiers
            if case .skipped = result {
                #expect(Bool(true))
            } else {
                Issue.record("Expected .skipped because phone not in allowed identifiers")
            }
        }
    }

    @Test
    func `Automatic linking checks both email and phone when both allowed`() async throws {
        try await withApp(configure: { app in
            try await configureWithAutomaticLinking(app, allowedIdentifiers: [.email, .phone])
        }) { app in
            // Create user with verified phone
            let existingUser = try await createTestUser(
                app: app,
                phone: "+9876543210",
                isPhoneVerified: true
            )

            // Identity has only phone (no email)
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "phone-link"),
                provider: .google,
                verifiedEmails: [],
                verifiedPhoneNumbers: ["+9876543210"],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: [.email, .phone],
                onAmbiguousMatch: .requestManualSelection,
            )

            if case .complete(let linkedUser) = result {
                #expect(linkedUser.id?.description == existingUser.id?.description)
            } else {
                Issue.record("Expected .complete result")
            }
        }
    }

    // MARK: - Edge Cases

    @Test
    func `Automatic linking handles empty verified emails list`() async throws {
        try await withApp(configure: { app in
            try await configureWithAutomaticLinking(app)
        }) { app in
            let identity = FederatedIdentity(
                identifier: .federated(.named("apple"), userId: "no-email"),
                provider: .named("apple"),
                verifiedEmails: [], // Apple sometimes doesn't share email
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let result = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: [.email],
                onAmbiguousMatch: .requestManualSelection
            )

            if case .skipped = result {
                #expect(Bool(true))
            } else {
                Issue.record("Expected .skipped when no verified emails")
            }
        }
    }

    @Test
    func `Automatic linking skips username and federated identifier kinds`() async throws {
        try await withApp(configure: { app in
            try await configureWithAutomaticLinking(app)
        }) { app in
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "test"),
                provider: .google,
                verifiedEmails: ["test@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())

            // Requesting username and federated kinds should result in skipped
            // because automatic linking doesn't support these
            let result = try await request.linking.automatic.perform(
                for: identity,
                withAllowedIdentifiers: [.username, .federated],
                onAmbiguousMatch: .requestManualSelection
            )

            if case .skipped = result {
                #expect(Bool(true))
            } else {
                Issue.record("Expected .skipped for unsupported identifier kinds")
            }
        }
    }
}

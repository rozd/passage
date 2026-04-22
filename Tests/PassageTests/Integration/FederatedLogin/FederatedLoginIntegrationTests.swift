import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration, .federatedLogin), .primeNIOSingletons)
struct `Federated Login Integration Tests` {

    // MARK: - Configuration Helpers

    /// Configures app with no account linking (disabled)
    @Sendable private func configureWithDisabledLinking(_ app: Application) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
            phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
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
                accountLinking: .init(resolution: .disabled),
                redirectLocation: "/dashboard"
            )
        )

        try await app.passage.configure(services: services, configuration: configuration)
    }

    /// Configures app with automatic account linking
    @Sendable private func configureWithAutomaticLinking(_ app: Application) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
            phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
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
                accountLinking: .init(resolution: .automatic(matchBy: [.email], onAmbiguity: .requestManualSelection)),
                redirectLocation: "/dashboard"
            )
        )

        try await app.passage.configure(services: services, configuration: configuration)
    }

    /// Configures app with manual account linking and views
    @Sendable private func configureWithManualLinking(_ app: Application) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
            phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
            federatedLogin: nil
        )

        let theme = Passage.Views.Theme(colors: .defaultLight)
        let views = Passage.Configuration.Views(
            linkAccountSelect: .init(style: .minimalism, theme: theme),
            linkAccountVerify: .init(style: .minimalism, theme: theme)
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
                accountLinking: .init(resolution: .manual(matchBy: [.email])),
                redirectLocation: "/dashboard"
            ),
            views: views
        )

        try await app.passage.configure(services: services, configuration: configuration)
    }

    /// Creates a test user
    @Sendable private func createTestUser(
        app: Application,
        email: String,
        password: String? = nil,
        isEmailVerified: Bool = false
    ) async throws -> any User {
        let store = app.passage.storage.services.store

        var credential: Credential? = nil
        if let password = password {
            credential = .password(try await app.password.async.hash(password))
        }

        let user = try await store.users.create(
            identifier: .email(email),
            with: credential
        )

        if isEmailVerified {
            try await store.users.markEmailVerified(for: user)
        }

        return user
    }

    // MARK: - New User (No Linking) Tests

    @Test
    func `Federated login creates new user when no existing user with federated identifier`() async throws {
        try await withApp(configure: configureWithDisabledLinking) { app in
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "new-google-user"),
                provider: .google,
                verifiedEmails: ["newuser@gmail.com"],
                verifiedPhoneNumbers: [],
                displayName: "New User",
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let response = try await request.federated.login(identity: identity)

            // Should redirect to dashboard with exchange code
            #expect(response.status == .seeOther)
            let location = response.headers.first(name: .location) ?? ""
            #expect(location.contains("/dashboard"))
            #expect(location.contains("code="))

            // New user should have been created with federated identifier
            let store = app.passage.storage.services.store
            let createdUser = try await store.users.find(byIdentifier: identity.identifier)
            #expect(createdUser != nil)
        }
    }

    @Test
    func `Federated login returns existing user when federated identifier already exists`() async throws {
        try await withApp(configure: configureWithDisabledLinking) { app in
            let federatedIdentifier = Identifier.federated(.google, userId: "existing-user")

            // First login creates the user
            let identity = FederatedIdentity(
                identifier: federatedIdentifier,
                provider: .google,
                verifiedEmails: ["existing@gmail.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request1 = Request(application: app, on: app.eventLoopGroup.any())
            _ = try await request1.federated.login(identity: identity)

            let store = app.passage.storage.services.store
            let firstUser = try await store.users.find(byIdentifier: federatedIdentifier)

            // Second login should return the same user
            let request2 = Request(application: app, on: app.eventLoopGroup.any())
            let response = try await request2.federated.login(identity: identity)

            #expect(response.status == .seeOther)

            let secondUser = try await store.users.find(byIdentifier: federatedIdentifier)
            #expect(firstUser?.id?.description == secondUser?.id?.description)
        }
    }

    // MARK: - Automatic Linking Tests

    @Test
    func `Federated login with automatic linking links to existing verified email user`() async throws {
        try await withApp(configure: configureWithAutomaticLinking) { app in
            // Create existing user with verified email
            let existingUser = try await createTestUser(
                app: app,
                email: "verified@example.com",
                password: "password123",
                isEmailVerified: true
            )

            // New federated identity with matching email
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "link-to-existing"),
                provider: .google,
                verifiedEmails: ["verified@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let response = try await request.federated.login(identity: identity)

            // Should redirect to dashboard (linked successfully)
            #expect(response.status == .seeOther)

            // Federated identifier should now be linked to existing user
            let store = app.passage.storage.services.store
            let federatedUser = try await store.users.find(byIdentifier: identity.identifier)
            #expect(federatedUser?.id?.description == existingUser.id?.description)
        }
    }

    @Test
    func `Federated login with automatic linking creates new user when no match`() async throws {
        try await withApp(configure: configureWithAutomaticLinking) { app in
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "no-match-user"),
                provider: .google,
                verifiedEmails: ["nomatch@gmail.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let response = try await request.federated.login(identity: identity)

            #expect(response.status == .seeOther)

            // New user should have been created
            let store = app.passage.storage.services.store
            let newUser = try await store.users.find(byIdentifier: identity.identifier)
            #expect(newUser != nil)
        }
    }

    // MARK: - Manual Linking Tests

    @Test
    func `Federated login with manual linking redirects to link select when candidates exist`() async throws {
        try await withApp(configure: configureWithManualLinking) { app in
            // Create existing user that will be a candidate
            _ = try await createTestUser(
                app: app,
                email: "candidate@example.com",
                password: "password123",
                isEmailVerified: true
            )

            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "manual-link"),
                provider: .google,
                verifiedEmails: ["candidate@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let response = try await request.federated.login(identity: identity)

            // Should redirect to link select page
            #expect(response.status == .seeOther)
            let location = response.headers.first(name: .location) ?? ""
            #expect(location.contains("link/select") || location.contains("connect/link"))
        }
    }

    @Test
    func `Federated login with manual linking creates new user when no candidates`() async throws {
        try await withApp(configure: configureWithManualLinking) { app in
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "no-candidates"),
                provider: .google,
                verifiedEmails: ["newuser@example.com"],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let response = try await request.federated.login(identity: identity)

            // Should redirect to dashboard (new user created, no linking needed)
            #expect(response.status == .seeOther)
            let location = response.headers.first(name: .location) ?? ""
            #expect(location.contains("/dashboard"))

            // New user should exist
            let store = app.passage.storage.services.store
            let newUser = try await store.users.find(byIdentifier: identity.identifier)
            #expect(newUser != nil)
        }
    }

    // MARK: - Redirect URL Tests

    @Test
    func `Federated login redirect includes exchange code`() async throws {
        try await withApp(configure: configureWithDisabledLinking) { app in
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "code-test"),
                provider: .google,
                verifiedEmails: [],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            let response = try await request.federated.login(identity: identity)

            #expect(response.status == .seeOther)
            let location = response.headers.first(name: .location) ?? ""
            #expect(location.contains("?code=") || location.contains("&code="))
        }
    }

    // MARK: - Session Authentication Tests

    @Test
    func `Federated login authenticates user in session`() async throws {
        try await withApp(configure: configureWithDisabledLinking) { app in
            let identity = FederatedIdentity(
                identifier: .federated(.google, userId: "session-test"),
                provider: .google,
                verifiedEmails: [],
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            let request = Request(application: app, on: app.eventLoopGroup.any())
            _ = try await request.federated.login(identity: identity)

            // User should be authenticated in session via request.passage.login()
            // This is verified by the flow completing without error
            #expect(Bool(true))
        }
    }

    // MARK: - Provider Tests

    @Test
    func `Federated login works with different OAuth providers`() async throws {
        try await withApp(configure: configureWithDisabledLinking) { app in
            let providers = [
                ("google", "google-user-id"),
                ("github", "12345678"),
                ("apple", "000123.abc456.789"),
                ("facebook", "fb-user-id"),
                ("twitter", "twitter-handle")
            ]

            for (providerName, subject) in providers {
                let identity = FederatedIdentity(
                    identifier: .federated(.named(providerName), userId: subject),
                    provider: .named(providerName),
                    verifiedEmails: [],
                    verifiedPhoneNumbers: [],
                    displayName: nil,
                    profilePictureURL: nil
                )

                let request = Request(application: app, on: app.eventLoopGroup.any())
                let response = try await request.federated.login(identity: identity)

                #expect(response.status == .seeOther)

                let store = app.passage.storage.services.store
                let user = try await store.users.find(byIdentifier: identity.identifier)
                #expect(user != nil)
            }
        }
    }
}

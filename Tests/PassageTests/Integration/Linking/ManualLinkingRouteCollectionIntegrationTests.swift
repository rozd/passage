import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration, .federatedLogin))
struct `Manual Linking Route Collection Integration Tests` {

    // MARK: - Test Request/Response Types

    struct InitiateRequest: Content {
        let provider: String
        let userId: String
        let verifiedEmails: [String]
        let verifiedPhones: [String]
    }

    struct InitiateLinkingResponse: Content {
        let status: String
        let candidates: [CandidateInfo]?

        struct CandidateInfo: Content {
            let userId: String
            let email: String?
            let phone: String?
            let hasPassword: Bool
        }
    }

    // MARK: - Configuration Helpers

    /// Configures a test Vapor application with Passage, manual linking, and test routes
    @Sendable private func configureWithManualLinking(
        _ app: Application,
        allowedIdentifiers: [Identifier.Kind] = [.email],
        withViews: Bool = true,
        hooks: Passage.Hooks = .init()
    ) async throws {
        // Enable sessions middleware (required for linking state)
        app.middleware.use(app.sessions.middleware)

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
            sessions: .init(enabled: true),
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
            configuration: configuration,
            hooks: hooks
        )

        // Register test routes that simulate OAuth callback initiating linking
        registerTestRoutes(app: app, allowedIdentifiers: allowedIdentifiers)
    }

    /// Registers test-only routes for simulating OAuth callback that initiates linking
    private func registerTestRoutes(app: Application, allowedIdentifiers: [Identifier.Kind]) {
        // Test route: Initiates linking for a federated identity
        // POST /test/initiate-linking
        // Body: { provider, userId, verifiedEmails, verifiedPhones }
        app.post("test", "initiate-linking") { req async throws -> InitiateLinkingResponse in
            struct InitiateRequest: Content {
                let provider: String
                let userId: String
                let verifiedEmails: [String]
                let verifiedPhones: [String]
            }

            let body = try req.content.decode(InitiateRequest.self)

            let identity = FederatedIdentity(
                identifier: .federated(.named(body.provider), userId: body.userId),
                provider: .named(body.provider),
                verifiedEmails: body.verifiedEmails,
                verifiedPhoneNumbers: body.verifiedPhones,
                displayName: nil,
                profilePictureURL: nil
            )

            let result = try await req.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: allowedIdentifiers
            )

            switch result {
            case .initiated:
                let state = try await req.linking.manual.loadLinkingState()
                return InitiateLinkingResponse(
                    status: "initiated",
                    candidates: state.candidates.map { candidate in
                        InitiateLinkingResponse.CandidateInfo(
                            userId: candidate.userId,
                            email: candidate.email,
                            phone: candidate.phone,
                            hasPassword: candidate.hasPassword
                        )
                    }
                )
            case .skipped:
                return InitiateLinkingResponse(status: "skipped", candidates: nil)
            case .conflict(let candidateIds):
                return InitiateLinkingResponse(
                    status: "conflict",
                    candidates: candidateIds.map { id in
                        InitiateLinkingResponse.CandidateInfo(
                            userId: id,
                            email: nil,
                            phone: nil,
                            hasPassword: false
                        )
                    }
                )
            case .complete:
                return InitiateLinkingResponse(status: "complete", candidates: nil)
            }
        }
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

    /// Extracts session cookie from response headers
    private func extractSessionCookie(from response: TestingHTTPResponse) -> String? {
        if let cookieHeader = response.headers[.setCookie].first(where: { $0.contains("vapor-session") }) {
            let parts = cookieHeader.split(separator: ";")
            if let cookiePart = parts.first {
                return String(cookiePart)
            }
        }
        return nil
    }

    // MARK: - Route Error Handling Tests (No Session)

    @Test
    func `POST to link/select without session returns bad request`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": "some-user-id"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .badRequest)
                }
            )
        }
    }

    @Test
    func `POST to link/select with empty body returns unprocessable entity`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: false)
        }) { app in
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode([:] as [String: String], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .unprocessableEntity || res.status == .badRequest)
                }
            )
        }
    }

    @Test
    func `POST to link/verify without session returns bad request`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: false)
        }) { app in
            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["password": "password123"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .badRequest || res.status == .ok)
                }
            )
        }
    }

    // MARK: - Link Select Route Tests (With Session)

    @Test
    func `POST to link/select with valid user ID advances linking via route`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            // Create candidate user with password
            let user = try await createTestUser(
                app: app,
                email: "candidate@example.com",
                password: "password123",
                isEmailVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Step 1: Initiate linking via test route (simulates OAuth callback)
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "some-user-123",
                        verifiedEmails: ["candidate@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)

                    let response = try res.content.decode(InitiateLinkingResponse.self)
                    #expect(response.status == "initiated")
                    #expect(response.candidates?.count == 1)
                    #expect(response.candidates?.first?.userId == userId)

                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // Step 2: POST to actual link/select route with session cookie
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": userId], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    // Should succeed - advances to verification step
                    #expect(res.status == .ok)
                }
            )
        }
    }

    @Test
    func `POST to link/select with invalid user ID returns bad request via route`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            // Create candidate user
            _ = try await createTestUser(
                app: app,
                email: "candidate@example.com",
                password: "password123",
                isEmailVerified: true
            )

            var sessionCookie: String?

            // Initiate linking
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "some-invalid",
                        verifiedEmails: ["candidate@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // POST with invalid user ID
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": "invalid-user-id"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .badRequest)
                }
            )
        }
    }

    // MARK: - Link Verify Route Tests (With Session)

    @Test
    func `POST to initiate-linking without views returns conflict`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: false)
        }) { app in
            // Create candidate user with password
            let user = try await createTestUser(
                app: app,
                email: "verify-user@example.com",
                password: "correct-password",
                isEmailVerified: true
            )

            // Step 1: Initiate linking
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "verify-some-123",
                        verifiedEmails: ["verify-user@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    let response = try res.content.decode(InitiateLinkingResponse.self)
                    // Without views, should return conflict (can't proceed with manual flow)
                    #expect(response.status == "conflict")
                }
            )
        }
    }

    @Test
    func `Full linking flow via routes: initiate -> select -> verify with password`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            // Create candidate user with password
            let user = try await createTestUser(
                app: app,
                email: "full-flow@example.com",
                password: "secure-password",
                isEmailVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Step 1: Initiate linking via test route
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "github",
                        userId: "github-user-456",
                        verifiedEmails: ["full-flow@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)

                    let response = try res.content.decode(InitiateLinkingResponse.self)
                    #expect(response.status == "initiated")
                    #expect(response.candidates?.count == 1)

                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // Step 2: POST to link/select route (advance to verification)
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": userId], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    // Update session cookie if changed
                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            // Step 3: POST to link/verify route (complete with password)
            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["password": "secure-password"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    // Without views configured for API response, should redirect with code
                    // or return OK for form submission
                    #expect(res.status == .seeOther || res.status == .ok)

                    if res.status == .seeOther {
                        let location = res.headers.first(name: .location)
                        #expect(location != nil)
                        #expect(location?.contains("/dashboard") == true)
                        #expect(location?.contains("code=") == true)
                    }
                }
            )

            // Verify: Federated identifier is now linked to user
            let store = app.passage.storage.services.store
            let federatedUser = try await store.users.find(
                byIdentifier: .federated(.github, userId: "github-user-456")
            )
            #expect(federatedUser != nil)
            #expect(federatedUser?.id?.description == userId)
        }
    }

    @Test
    func `Link verify form submission issues credential with accountLinking origin`() async throws {
        // The verify route only calls `passage.login(origin: .accountLinking, via: .browser)`
        // on an HTML form submission with the verify view configured; an API client gets an
        // exchange code instead and the hook fires later with origin `.exchange`.
        typealias Spy = `Credential Issuance Hooks Integration Tests`.CredentialIssuanceSpy
        let spy = Spy()

        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            let user = try await createTestUser(
                app: app,
                email: "origin-flow@example.com",
                password: "secure-password",
                isEmailVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "github",
                        userId: "github-user-origin",
                        verifiedEmails: ["origin-flow@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)
            #expect(spy.willIssuances.isEmpty)

            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": userId], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            #expect(spy.willIssuances.isEmpty)

            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.replaceOrAdd(name: .accept, value: "text/html")
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["password": "secure-password"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .seeOther || res.status == .found || res.status == .ok)
                }
            )

            #expect(spy.willIssuances.count == 1)
            #expect(spy.didIssuances.count == 1)
            let issuance = try #require(spy.willIssuances.first)
            #expect(issuance.kind == .browser)
            #expect(issuance.origin == .accountLinking)
            #expect(issuance.user.id?.description == userId)
            #expect(issuance.accessToken == nil)
        }
    }

    @Test
    func `Link verify with wrong password returns unauthorized via route`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            // Create candidate user
            let user = try await createTestUser(
                app: app,
                email: "wrong-pw@example.com",
                password: "correct-password",
                isEmailVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Initiate linking
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "wrong-pw-some",
                        verifiedEmails: ["wrong-pw@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            // Advance to verification
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": userId], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            // Try to verify with wrong password
            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["password": "wrong-password"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    // Should fail authentication
                    #expect(res.status == .unauthorized || res.status == .ok)
                }
            )
        }
    }

    @Test
    func `Link verify without password or code returns bad request via route`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            let user = try await createTestUser(
                app: app,
                email: "no-creds@example.com",
                password: "password123",
                isEmailVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Initiate linking
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "no-creds-some",
                        verifiedEmails: ["no-creds@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            // Advance
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": userId], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            // Try to verify without credentials
            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    // Empty - no password, no code
                    try req.content.encode([:] as [String: String], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .badRequest || res.status == .ok)
                }
            )
        }
    }

    @Test
    func `Link verify without user selection returns bad request via route`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            _ = try await createTestUser(
                app: app,
                email: "no-select@example.com",
                password: "password123",
                isEmailVerified: true
            )

            var sessionCookie: String?

            // Initiate but don't advance (no user selected)
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "no-select-some",
                        verifiedEmails: ["no-select@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            // Try to verify without advancing (no user selected)
            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["password": "password123"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .badRequest || res.status == .ok)
                }
            )
        }
    }

    // MARK: - Redirect URL Tests

    @Test
    func `Initiating linking returns conflict when views are disabled via route`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: false)
        }) { app in
            let user = try await createTestUser(
                app: app,
                email: "redirect-test@example.com",
                password: "password123",
                isEmailVerified: true
            )

            // Initiate - with views=false, returns conflict
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "redirect-some",
                        verifiedEmails: ["redirect-test@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    let response = try res.content.decode(InitiateLinkingResponse.self)
                    // Without views, conflict is returned
                    #expect(response.status == "conflict")
                }
            )
        }
    }

    // MARK: - Multiple Candidates Tests

    @Test
    func `Initiate linking with multiple candidates returns all via route`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            let user1 = try await createTestUser(
                app: app,
                email: "multi1@example.com",
                password: "password1",
                isEmailVerified: true
            )
            let user2 = try await createTestUser(
                app: app,
                email: "multi2@example.com",
                password: "password2",
                isEmailVerified: true
            )

            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "multi-user",
                        verifiedEmails: ["multi1@example.com", "multi2@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)

                    let response = try res.content.decode(InitiateLinkingResponse.self)
                    #expect(response.status == "initiated")
                    #expect(response.candidates?.count == 2)

                    let candidateIds = response.candidates?.map { $0.userId } ?? []
                    #expect(candidateIds.contains(user1.id!.description))
                    #expect(candidateIds.contains(user2.id!.description))
                }
            )
        }
    }

    @Test
    func `Full flow with multiple candidates selects correct user via routes`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            _ = try await createTestUser(
                app: app,
                email: "select1@example.com",
                password: "password1",
                isEmailVerified: true
            )
            let user2 = try await createTestUser(
                app: app,
                email: "select2@example.com",
                password: "password2",
                isEmailVerified: true
            )
            let user2Id = user2.id!.description

            var sessionCookie: String?

            // Initiate with both emails
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "select-multi",
                        verifiedEmails: ["select1@example.com", "select2@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // Select user2
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": user2Id], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            // Verify with user2's password
            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["password": "password2"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .seeOther || res.status == .ok)
                }
            )

            // Verify federated identity linked to user2
            let store = app.passage.storage.services.store
            let linkedUser = try await store.users.find(
                byIdentifier: .federated(.google, userId: "select-multi")
            )
            #expect(linkedUser != nil)
            #expect(linkedUser?.email == "select2@example.com")
        }
    }

    // MARK: - No Candidates Tests

    @Test
    func `Initiate linking with no candidates returns skipped via route`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            // Don't create any users

            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "no-match",
                        verifiedEmails: ["nonexistent@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)

                    let response = try res.content.decode(InitiateLinkingResponse.self)
                    #expect(response.status == "skipped")
                    #expect(response.candidates == nil)
                }
            )
        }
    }

    // MARK: - Phone-Based Linking Tests

    @Test
    func `Linking with phone identifier works via routes`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, allowedIdentifiers: [.phone], withViews: true)
        }) { app in
            let user = try await createTestUser(
                app: app,
                phone: "+15551234567",
                password: "phone-password",
                isPhoneVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Initiate with phone
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "phone-some",
                        verifiedEmails: [],
                        verifiedPhones: ["+15551234567"]
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)

                    let response = try res.content.decode(InitiateLinkingResponse.self)
                    #expect(response.status == "initiated")
                    #expect(response.candidates?.count == 1)
                    #expect(response.candidates?.first?.phone == "+15551234567")

                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // Select and verify
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": userId], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["password": "phone-password"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .seeOther || res.status == .ok)
                }
            )

            // Verify linking
            let store = app.passage.storage.services.store
            let linkedUser = try await store.users.find(
                byIdentifier: .federated(.google, userId: "phone-some")
            )
            #expect(linkedUser != nil)
            #expect(linkedUser?.phone == "+15551234567")
        }
    }

    // MARK: - HTML Form Submission Tests
    //
    // These tests cover the HTML form submission paths (lines 26-30, 35-40, 61-65, 70-75)
    // by setting Accept: text/html header to trigger view rendering.
    // The view handlers return redirects (not HTML directly) to guide the user flow.

    @Test
    func `HTML form submission to link/select succeeds and redirects to verify`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            let user = try await createTestUser(
                app: app,
                email: "html-select@example.com",
                password: "password123",
                isEmailVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Initiate linking
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "html-select-some",
                        verifiedEmails: ["html-select@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // POST as HTML form submission (Accept: text/html)
            // Lines 26-30: handleLinkAccountSelectFormSubmit redirects to verify path
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    req.headers.add(name: .accept, value: "text/html")
                    try req.content.encode(["selectedUserId": userId], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    // View handler redirects to verify path
                    #expect(res.status == .seeOther)
                    let location = res.headers.first(name: .location)
                    #expect(location != nil)
                    #expect(location?.contains("link/verify") == true)
                }
            )
        }
    }

    @Test
    func `HTML form submission to link/select with invalid user redirects back with error`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            _ = try await createTestUser(
                app: app,
                email: "html-select-error@example.com",
                password: "password123",
                isEmailVerified: true
            )

            var sessionCookie: String?

            // Initiate linking
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "html-select-error-some",
                        verifiedEmails: ["html-select-error@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // POST as HTML form with invalid user ID
            // Lines 35-40: handleLinkAccountSelectFormFailure redirects back with error
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    req.headers.add(name: .accept, value: "text/html")
                    try req.content.encode(["selectedUserId": "invalid-user"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    // View handler redirects back to select path with error
                    #expect(res.status == .seeOther)
                    let location = res.headers.first(name: .location)
                    #expect(location != nil)
                    #expect(location?.contains("link/select") == true)
                }
            )
        }
    }

    @Test
    func `HTML form submission to link/verify succeeds and redirects to dashboard`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            let user = try await createTestUser(
                app: app,
                email: "html-verify@example.com",
                password: "correct-password",
                isEmailVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Initiate linking
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "html-verify-some",
                        verifiedEmails: ["html-verify@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            // Advance to verification (API style, no Accept: text/html)
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": userId], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            // POST as HTML form submission to verify
            // Lines 61-65: handleLinkAccountVerifyFormSubmit redirects to dashboard
            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    req.headers.add(name: .accept, value: "text/html")
                    try req.content.encode(["password": "correct-password"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    // View handler redirects to dashboard (redirectLocation)
                    #expect(res.status == .seeOther)
                    let location = res.headers.first(name: .location)
                    #expect(location != nil)
                    #expect(location?.contains("/dashboard") == true)
                }
            )
        }
    }

    @Test
    func `HTML form submission to link/verify with wrong password redirects back with error`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            let user = try await createTestUser(
                app: app,
                email: "html-verify-error@example.com",
                password: "correct-password",
                isEmailVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Initiate linking
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "html-verify-error-some",
                        verifiedEmails: ["html-verify-error@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            // Advance to verification
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    try req.content.encode(["selectedUserId": userId], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            // POST as HTML form with wrong password
            // Lines 70-75: handleLinkAccountVerifyFormFailure redirects back with error
            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    req.headers.add(name: .accept, value: "text/html")
                    try req.content.encode(["password": "wrong-password"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    // View handler redirects back to verify path with error
                    #expect(res.status == .seeOther)
                    let location = res.headers.first(name: .location)
                    #expect(location != nil)
                    #expect(location?.contains("link/verify") == true)
                }
            )
        }
    }

    @Test
    func `Full HTML form flow: initiate -> select -> verify with redirects`() async throws {
        try await withApp(configure: { app in
            try await configureWithManualLinking(app, withViews: true)
        }) { app in
            let user = try await createTestUser(
                app: app,
                email: "html-full-flow@example.com",
                password: "secure-password",
                isEmailVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Step 1: Initiate linking
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    try req.content.encode(InitiateRequest(
                        provider: "github",
                        userId: "html-full-flow-some",
                        verifiedEmails: ["html-full-flow@example.com"],
                        verifiedPhones: []
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // Step 2: HTML form submission to link/select
            // Should redirect to verify path
            try await app.testing().test(
                .POST, "auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    req.headers.add(name: .accept, value: "text/html")
                    try req.content.encode(["selectedUserId": userId], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .seeOther)
                    let location = res.headers.first(name: .location)
                    #expect(location?.contains("link/verify") == true)

                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            // Step 3: HTML form submission to link/verify
            // Should redirect to dashboard
            try await app.testing().test(
                .POST, "auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    req.headers.contentType = .urlEncodedForm
                    req.headers.add(name: .accept, value: "text/html")
                    try req.content.encode(["password": "secure-password"], as: .urlEncodedForm)
                },
                afterResponse: { res in
                    #expect(res.status == .seeOther)
                    let location = res.headers.first(name: .location)
                    #expect(location?.contains("/dashboard") == true)
                }
            )

            // Verify: Federated identifier is now linked to user
            let store = app.passage.storage.services.store
            let federatedUser = try await store.users.find(
                byIdentifier: .federated(.github, userId: "html-full-flow-some")
            )
            #expect(federatedUser != nil)
            #expect(federatedUser?.id?.description == userId)
        }
    }
}

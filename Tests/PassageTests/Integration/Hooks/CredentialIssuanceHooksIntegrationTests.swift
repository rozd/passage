import Foundation
import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration, .hooks))
struct `Credential Issuance Hooks Integration Tests` {

    private struct TestPolicyError: AbortError {
        let status: HTTPResponseStatus = .forbidden
        let reason: String = "Blocked by hook"
    }

    final class CredentialIssuanceSpy: @unchecked Sendable {
        var willIssuances: [CredentialIssuance] = []
        var didIssuances: [CredentialIssuance] = []
        var willThrowError: (any Error)?
        var willThrowForKind: CredentialIssuance.Kind?

        func makeAccountHook() -> any Passage.Hooks.Account {
            _AccountHooksClosures.hook(
                willIssueCredential: { [self] issuance, _ in
                    self.willIssuances.append(issuance)
                    if let error = self.willThrowError,
                       self.willThrowForKind == nil || self.willThrowForKind == issuance.kind {
                        throw error
                    }
                },
                didIssueCredential: { [self] issuance, _ in
                    self.didIssuances.append(issuance)
                }
            )
        }
    }

    final class TransactionSpyStore: Passage.Store {
        let inner: any Passage.Store
        let isTransactionBound: Bool

        init(inner: any Passage.Store, isTransactionBound: Bool = false) {
            self.inner = inner
            self.isTransactionBound = isTransactionBound
        }

        var users: any Passage.UserStore { inner.users }
        var tokens: any Passage.TokenStore { inner.tokens }
        var verificationCodes: any Passage.VerificationCodeStore { inner.verificationCodes }
        var restorationCodes: any Passage.RestorationCodeStore { inner.restorationCodes }
        var magicLinkTokens: any Passage.MagicLinkTokenStore { inner.magicLinkTokens }
        var exchangeTokens: any Passage.ExchangeTokenStore { inner.exchangeTokens }
        var passkeyCredentials: (any Passage.PasskeyCredentialStore)? { inner.passkeyCredentials }
        var passkeyChallenges: (any Passage.PasskeyChallengeStore)? { inner.passkeyChallenges }

        func transaction<T: Sendable>(
            _ body: @Sendable (any Passage.Store) async throws -> T
        ) async throws -> T {
            try await inner.transaction { bound in
                try await body(TransactionSpyStore(inner: bound, isTransactionBound: true))
            }
        }
    }

    final class CapturedEmails: @unchecked Sendable {
        var emails: [Passage.OnlyForTest.MockEmailDelivery.EphemeralEmail] = []
    }

    @Sendable private func configure(
        _ app: Application,
        hooks: Passage.Hooks = .init(),
        sessionsEnabled: Bool = false,
        capturedEmails: CapturedEmails? = nil,
        store: (any Passage.Store)? = nil,
        tokenConcurrency: Passage.Configuration.Tokens.RefreshToken.Concurrency = .unlimited
    ) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        if sessionsEnabled {
            app.middleware.use(app.sessions.middleware)
        }

        let store = store ?? Passage.OnlyForTest.InMemoryStore()
        let emailDelivery: (any Passage.EmailDelivery)? = capturedEmails.map { captured in
            Passage.OnlyForTest.MockEmailDelivery(callback: { @Sendable in captured.emails.append($0) })
        }
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: emailDelivery,
            phoneDelivery: nil,
            federatedLogin: nil
        )

        let emptyJwks = """
        {"keys":[]}
        """

        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = sessionsEnabled ? Passage.Configuration.Views(login: loginView) : Passage.Configuration.Views()

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400, concurrency: tokenConcurrency)
            ),
            sessions: .init(enabled: sessionsEnabled),
            jwt: .init(jwks: .init(json: emptyJwks)),
            passwordless: .init(
                emailMagicLink: .email(
                    useQueues: false,
                    linkExpiration: 3600,
                    maxAttempts: 3,
                    autoCreateUser: true,
                    requireSameBrowser: false
                )
            ),
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
            views: viewsConfig
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration,
            hooks: hooks
        )
    }

    @Sendable private func createTestUser(
        app: Application,
        email: String = "user@example.com",
        password: String = "password123"
    ) async throws -> String {
        let store = app.passage.storage.services.store
        let passwordHash = try await app.password.async.hash(password)
        let identifier = Identifier.email(email)
        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)
        try await store.users.markEmailVerified(for: user)
        return user.id as! String
    }

    @Test
    func `password login with throwing willIssueCredential returns 403 and stores no token`() async throws {
        let spy = CredentialIssuanceSpy()
        spy.willThrowError = TestPolicyError()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            try await createTestUser(app: app, email: "user1@test.com")

            let store = app.passage.storage.services.store
            let tokenCountBefore = (store.tokens as! Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore).refreshTokens.count

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "user1@test.com", "password": "password123"])
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            let tokenCountAfter = (store.tokens as! Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore).refreshTokens.count
            #expect(tokenCountBefore == tokenCountAfter)
            #expect(spy.didIssuances.isEmpty)
        }
    }

    @Test
    func `password login with succeeding willIssueCredential returns 200 and creates token`() async throws {
        let spy = CredentialIssuanceSpy()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            let userId = try await createTestUser(app: app, email: "user2@test.com")

            var accessToken: String = ""
            var refreshToken: String = ""

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "user2@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                accessToken = authUser.accessToken
                refreshToken = authUser.refreshToken
            })

            #expect(spy.willIssuances.count == 1)
            #expect(spy.didIssuances.count == 1)

            let issuance = spy.willIssuances[0]
            #expect(issuance.kind == .bearer)
            #expect(issuance.origin == .login)
            #expect(issuance.accessToken == accessToken)
            #expect(issuance.accessTokenExpiresAt != nil)
            #expect(issuance.refreshTokenExpiresAt != nil)

            let decodedToken = try await app.jwt.keys.verify(accessToken, as: AccessToken.self)
            #expect(decodedToken.sessionId == issuance.sessionId)
            #expect(decodedToken.subject.value == userId)

            let store = app.passage.storage.services.store
            let tokenStore = store.tokens as! Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore
            let random = app.passage.storage.services.random
            let refreshTokenHash = random.hashOpaqueToken(token: refreshToken)
            let refreshTokenRow = try await store.tokens.find(refreshTokenHash: refreshTokenHash)
            #expect(refreshTokenRow?.sessionId == issuance.sessionId)
        }
    }

    @Test
    func `second password login revokes first login's sessionId`() async throws {
        let spy = CredentialIssuanceSpy()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()), tokenConcurrency: .single)
        }) { app in
            let userId = try await createTestUser(app: app, email: "user3@test.com")

            var firstSessionId: UUID?

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "user3@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                let decodedToken = try await app.jwt.keys.verify(authUser.accessToken, as: AccessToken.self)
                firstSessionId = decodedToken.sessionId
            })

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "user3@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
            })

            #expect(spy.willIssuances.count == 2)
            let secondIssuance = spy.willIssuances[1]
            #expect(secondIssuance.revokedSessionIds == [firstSessionId!])
        }
    }


    @Test
    func `refresh token with throwing willIssueCredential returns 403 and stores no new token`() async throws {
        let spy = CredentialIssuanceSpy()
        spy.willThrowForKind = .bearer

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            let userId = try await createTestUser(app: app, email: "refresh1@test.com")

            var refreshToken = ""
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "refresh1@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                refreshToken = authUser.refreshToken
            })

            spy.willThrowError = TestPolicyError()

            let store = app.passage.storage.services.store
            let tokenCountBefore = (store.tokens as! Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore).refreshTokens.count

            try await app.testing().test(.POST, "auth/refresh-token", beforeRequest: { req in
                try req.content.encode(["refreshToken": refreshToken])
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            let tokenCountAfter = (store.tokens as! Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore).refreshTokens.count
            #expect(tokenCountBefore == tokenCountAfter)
        }
    }

    @Test
    func `refresh token with succeeding willIssueCredential returns 200`() async throws {
        let spy = CredentialIssuanceSpy()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            let userId = try await createTestUser(app: app, email: "refresh2@test.com")

            var refreshToken = ""
            var firstSessionId: UUID?
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "refresh2@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                refreshToken = authUser.refreshToken
                let decodedToken = try await app.jwt.keys.verify(authUser.accessToken, as: AccessToken.self)
                firstSessionId = decodedToken.sessionId
            })

            spy.willIssuances.removeAll()
            spy.didIssuances.removeAll()

            try await app.testing().test(.POST, "auth/refresh-token", beforeRequest: { req in
                try req.content.encode(["refreshToken": refreshToken])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
            })

            #expect(spy.willIssuances.count == 1)
            #expect(spy.didIssuances.count == 1)
            let issuance = spy.willIssuances[0]
            #expect(issuance.origin == .refresh)
            #expect(issuance.sessionId == firstSessionId)
            #expect(issuance.revokedSessionIds.isEmpty)
        }
    }

    @Test
    func `browser login with throwing willIssueCredential (browser) returns 303 and no session cookie`() async throws {
        let spy = CredentialIssuanceSpy()
        spy.willThrowForKind = .browser

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()), sessionsEnabled: true)
        }) { app in
            try await createTestUser(app: app, email: "browser1@test.com")

            spy.willThrowError = TestPolicyError()

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .accept, value: "text/html")
                try req.content.encode(["email": "browser1@test.com", "password": "password123"], as: .urlEncodedForm)
            }, afterResponse: { res async in
                #expect(res.status == .seeOther || res.status == .found)
                let hasSessionCookie = res.headers[.setCookie].contains { $0.contains("vapor-session") }
                #expect(!hasSessionCookie)
            })

            #expect(spy.didIssuances.isEmpty)
        }
    }

    @Test
    func `form login with sessions enabled yields one browser issuance and no refresh token`() async throws {
        let spy = CredentialIssuanceSpy()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()), sessionsEnabled: true)
        }) { app in
            try await createTestUser(app: app, email: "browser2@test.com")
            let tokenCountBefore = tokenStore(app).refreshTokens.count

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .accept, value: "text/html")
                try req.content.encode(["email": "browser2@test.com", "password": "password123"], as: .urlEncodedForm)
            }, afterResponse: { res async throws in
                #expect(res.status == .seeOther || res.status == .found)
                let hasSessionCookie = res.headers[.setCookie].contains { $0.contains("vapor-session") }
                #expect(hasSessionCookie)
            })

            #expect(tokenStore(app).refreshTokens.count == tokenCountBefore)
            #expect(spy.willIssuances.count == 1)
            #expect(spy.didIssuances.count == 1)

            let issuance = try #require(spy.willIssuances.first)
            #expect(issuance.kind == .browser)
            #expect(issuance.origin == .login)
            #expect(issuance.accessToken == nil)
            #expect(issuance.refreshTokenExpiresAt == nil)
        }
    }

    @Test
    func `form login hands willIssueCredential a transaction-bound store`() async throws {
        let spy = CredentialIssuanceSpy()
        let store = TransactionSpyStore(inner: Passage.OnlyForTest.InMemoryStore())

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()), sessionsEnabled: true, store: store)
        }) { app in
            try await createTestUser(app: app, email: "browser4@test.com")

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .accept, value: "text/html")
                try req.content.encode(["email": "browser4@test.com", "password": "password123"], as: .urlEncodedForm)
            }, afterResponse: { res async in
                #expect(res.status == .seeOther || res.status == .found)
            })

            let issuance = try #require(spy.willIssuances.first)
            #expect(issuance.kind == .browser)
            let issuanceStore = try #require(issuance.store as? TransactionSpyStore)
            #expect(issuanceStore.isTransactionBound)
            #expect(!store.isTransactionBound)
        }
    }

    @Test
    func `JSON login hands willIssueCredential a transaction-bound store`() async throws {
        let spy = CredentialIssuanceSpy()
        let store = TransactionSpyStore(inner: Passage.OnlyForTest.InMemoryStore())

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()), store: store)
        }) { app in
            try await createTestUser(app: app, email: "bearer4@test.com")

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "bearer4@test.com", "password": "password123"])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let issuance = try #require(spy.willIssuances.first)
            #expect(issuance.kind == .bearer)
            let issuanceStore = try #require(issuance.store as? TransactionSpyStore)
            #expect(issuanceStore.isTransactionBound)
        }
    }

    @Test
    func `JSON login with sessions enabled yields one bearer issuance and no cookie`() async throws {
        let spy = CredentialIssuanceSpy()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()), sessionsEnabled: true)
        }) { app in
            try await createTestUser(app: app, email: "browser3@test.com")

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["email": "browser3@test.com", "password": "password123"])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let hasSessionCookie = res.headers[.setCookie].contains { $0.contains("vapor-session") }
                #expect(!hasSessionCookie)
            })

            #expect(spy.willIssuances.count == 1)
            #expect(spy.didIssuances.count == 1)

            let issuance = try #require(spy.willIssuances.first)
            #expect(issuance.kind == .bearer)
            #expect(issuance.origin == .login)
            #expect(issuance.accessToken != nil)
        }
    }

    private func tokenStore(_ app: Application) -> Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore {
        app.passage.storage.services.store.tokens as! Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore
    }

    private func requestMagicLinkToken(app: Application, captured: CapturedEmails, email: String) async throws -> String {
        try await app.testing().test(.POST, "auth/magic-link/email", beforeRequest: { req in
            try req.content.encode(["email": email])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })
        let url = try #require(captured.emails.last?.magicLinkURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let token = try #require(components.queryItems?.first(where: { $0.name == "token" })?.value)
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+/=")
        return try #require(token.addingPercentEncoding(withAllowedCharacters: allowed))
    }

    private func createExchangeCode(app: Application, userId: String) async throws -> String {
        let store = app.passage.storage.services.store
        let random = app.passage.storage.services.random
        let user = try #require(try await store.users.find(byId: userId))
        let code = random.generateOpaqueToken()
        try await store.exchangeTokens.createExchangeToken(
            for: user,
            tokenHash: random.hashOpaqueToken(token: code),
            expiresAt: Date().addingTimeInterval(60)
        )
        return code
    }

    private func assertBearerIssuance(
        app: Application,
        spy: CredentialIssuanceSpy,
        origin: CredentialIssuance.Origin,
        accessToken: String,
        refreshToken: String
    ) async throws {
        #expect(spy.willIssuances.count == 1)
        #expect(spy.didIssuances.count == 1)
        let issuance = try #require(spy.willIssuances.first)
        #expect(issuance.kind == .bearer)
        #expect(issuance.origin == origin)
        #expect(issuance.accessToken == accessToken)
        #expect(issuance.accessTokenExpiresAt != nil)
        #expect(issuance.refreshTokenExpiresAt != nil)
        let decoded = try await app.jwt.keys.verify(accessToken, as: AccessToken.self)
        #expect(decoded.sessionId == issuance.sessionId)
        let hash = app.passage.storage.services.random.hashOpaqueToken(token: refreshToken)
        let row = try await app.passage.storage.services.store.tokens.find(refreshTokenHash: hash)
        #expect(row?.sessionId == issuance.sessionId)
    }

    @Test
    func `magic link verify with throwing willIssueCredential returns 403 and stores no token`() async throws {
        let spy = CredentialIssuanceSpy()
        spy.willThrowError = TestPolicyError()
        let captured = CapturedEmails()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()), capturedEmails: captured)
        }) { app in
            let token = try await requestMagicLinkToken(app: app, captured: captured, email: "magic-fail@test.com")
            let before = tokenStore(app).refreshTokens.count

            try await app.testing().test(.GET, "auth/magic-link/email/verify?token=\(token)", afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            #expect(tokenStore(app).refreshTokens.count == before)
            #expect(spy.willIssuances.count == 1)
            #expect(spy.didIssuances.isEmpty)
        }
    }

    @Test
    func `magic link verify with succeeding willIssueCredential returns 200 and creates token`() async throws {
        let spy = CredentialIssuanceSpy()
        let captured = CapturedEmails()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()), capturedEmails: captured)
        }) { app in
            let token = try await requestMagicLinkToken(app: app, captured: captured, email: "magic-ok@test.com")

            var accessToken = ""
            var refreshToken = ""
            try await app.testing().test(.GET, "auth/magic-link/email/verify?token=\(token)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                accessToken = authUser.accessToken
                refreshToken = authUser.refreshToken
            })

            try await assertBearerIssuance(app: app, spy: spy, origin: .magicLink, accessToken: accessToken, refreshToken: refreshToken)
        }
    }

    @Test
    func `exchange code with throwing willIssueCredential returns 403 and stores no token`() async throws {
        let spy = CredentialIssuanceSpy()
        spy.willThrowError = TestPolicyError()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            let userId = try await createTestUser(app: app, email: "exchange-fail@test.com")
            let code = try await createExchangeCode(app: app, userId: userId)
            let before = tokenStore(app).refreshTokens.count

            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode(["code": code])
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            #expect(tokenStore(app).refreshTokens.count == before)
            #expect(spy.willIssuances.count == 1)
            #expect(spy.didIssuances.isEmpty)
        }
    }

    @Test
    func `exchange code with succeeding willIssueCredential returns 200 and creates token`() async throws {
        let spy = CredentialIssuanceSpy()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            let userId = try await createTestUser(app: app, email: "exchange-ok@test.com")
            let code = try await createExchangeCode(app: app, userId: userId)

            var accessToken = ""
            var refreshToken = ""
            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode(["code": code])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                accessToken = authUser.accessToken
                refreshToken = authUser.refreshToken
            })

            try await assertBearerIssuance(app: app, spy: spy, origin: .exchange, accessToken: accessToken, refreshToken: refreshToken)
        }
    }

    @Test
    func `exchange code with sessions enabled yields one bearer issuance and no cookie`() async throws {
        let spy = CredentialIssuanceSpy()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()), sessionsEnabled: true)
        }) { app in
            let userId = try await createTestUser(app: app, email: "exchange-sessions@test.com")
            let code = try await createExchangeCode(app: app, userId: userId)

            try await app.testing().test(.POST, "auth/token/exchange", beforeRequest: { req in
                try req.content.encode(["code": code])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let hasSessionCookie = res.headers[.setCookie].contains { $0.contains("vapor-session") }
                #expect(!hasSessionCookie)
            })

            #expect(spy.willIssuances.count == 1)
            #expect(spy.didIssuances.count == 1)

            let issuance = try #require(spy.willIssuances.first)
            #expect(issuance.kind == .bearer)
            #expect(issuance.origin == .exchange)
        }
    }

    @Test
    func `magic link verify issues credential with magicLink origin`() async throws {
        let spy = CredentialIssuanceSpy()
        let captured = CapturedEmails()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()), capturedEmails: captured)
        }) { app in
            let token = try await requestMagicLinkToken(app: app, captured: captured, email: "magic-origin@test.com")

            var accessToken = ""
            var refreshToken = ""
            try await app.testing().test(.GET, "auth/magic-link/email/verify?token=\(token)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                accessToken = authUser.accessToken
                refreshToken = authUser.refreshToken
            })

            try await assertBearerIssuance(app: app, spy: spy, origin: .magicLink, accessToken: accessToken, refreshToken: refreshToken)
        }
    }

    @Test
    func `federated login with sessions enabled issues credential with federatedLogin origin`() async throws {
        let spy = CredentialIssuanceSpy()

        try await withApp(configure: { app in
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

            let emptyJwks = """
            {"keys":[]}
            """

            let loginView = Passage.Configuration.Views.LoginView(
                style: .minimalism,
                theme: Passage.Views.Theme(colors: .defaultLight),
                identifier: .email
            )
            let viewsConfig = Passage.Configuration.Views(login: loginView)

            let configuration = try Passage.Configuration(
                origin: URL(string: "http://localhost:8080")!,
                routes: .init(),
                tokens: .init(
                    issuer: "test-issuer",
                    accessToken: .init(timeToLive: 3600),
                    refreshToken: .init(timeToLive: 86400)
                ),
                sessions: .init(enabled: true),
                jwt: .init(jwks: .init(json: emptyJwks)),
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
                ),
                views: viewsConfig
            )

            let hooks = Passage.Hooks(
                account: spy.makeAccountHook()
            )

            try await app.passage.configure(
                services: services,
                configuration: configuration,
                hooks: hooks
            )

            // Register a test route to call federated login through the middleware chain
            app.post("test", "federated-login") { req async throws -> String in
                let identity = FederatedIdentity(
                    identifier: .federated(.google, userId: "fed-user-hook-test"),
                    provider: .google,
                    verifiedEmails: [],
                    verifiedPhoneNumbers: [],
                    displayName: nil,
                    profilePictureURL: nil
                )

                _ = try await req.federated.login(identity: identity)
                return "ok"
            }
        }) { app in
            try await app.testing().test(.POST, "test/federated-login", afterResponse: { res async in
                #expect(res.status == .ok)
            })

            #expect(spy.willIssuances.count == 1)
            #expect(spy.didIssuances.count == 1)
            let issuance = try #require(spy.willIssuances.first)
            #expect(issuance.kind == .browser)
            #expect(issuance.origin == .federatedLogin)
        }
    }

    @Test
    func `passkey authentication finish with sessions enabled issues credential with passkey origin`() async throws {
        let spy = CredentialIssuanceSpy()
        let sharedChallengeBytes = MockPasskeyService.sharedChallengeBytes
        let sharedCredentialID = "credential-id-mock"

        try await withApp(configure: { app in
            app.middleware.use(app.sessions.middleware)

            await app.jwt.keys.add(
                hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
                digestAlgorithm: .sha256,
                kid: JWKIdentifier(string: "test-key")
            )

            let store = Passage.OnlyForTest.InMemoryStore()
            let service = MockPasskeyService()

            let services = Passage.Services(
                store: store,
                random: DefaultRandomGenerator(),
                emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
                phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
                federatedLogin: nil,
                passkey: service
            )

            let emptyJwks = """
            {"keys":[]}
            """

            let configuration = try Passage.Configuration(
                origin: URL(string: "http://localhost:8080")!,
                tokens: .init(
                    issuer: "test-issuer",
                    accessToken: .init(timeToLive: 3600),
                    refreshToken: .init(timeToLive: 86400)
                ),
                sessions: .init(enabled: true),
                jwt: .init(jwks: .init(json: emptyJwks)),
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
                passkey: .init()
            )

            let hooks = Passage.Hooks(
                account: spy.makeAccountHook()
            )

            try await app.passage.configure(services: services, configuration: configuration, hooks: hooks)

            // Seed the user + credential + challenge
            let user = try await store.users.create(
                identifier: .email("passkey-hook@example.com"),
                with: nil
            )

            if let credentials = store.passkeyCredentials {
                _ = try await credentials.createPasskeyCredential(
                    for: user,
                    from: PasskeyCredential(
                        credentialID: sharedCredentialID,
                        publicKey: Data([0x04, 0xDE, 0xAD]),
                        signCount: 0,
                        uvInitialized: false,
                        transports: [.internal],
                        backupEligible: false,
                        isBackedUp: false,
                        aaguid: nil,
                        attestationFormat: nil
                    )
                )
            }

            if let challenges = store.passkeyChallenges {
                _ = try await challenges.createPasskeyChallenge(
                    from: PasskeyChallenge(
                        bytes: sharedChallengeBytes,
                        kind: .authentication,
                        expiresAt: Date().addingTimeInterval(300)
                    )
                )
            }
        }) { app in
            let minimalFinishBody = #"{"id":"credential-id-mock","rawId":"credential-id-mock","type":"public-key","response":{"clientDataJSON":"","authenticatorData":"","signature":""}}"#

            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: minimalFinishBody)
            ) { res in
                #expect(res.status == .ok)
            }

            #expect(spy.willIssuances.count == 1)
            #expect(spy.didIssuances.count == 1)
            let issuance = try #require(spy.willIssuances.first)
            #expect(issuance.kind == .browser)
            #expect(issuance.origin == .passkey)
        }
    }


}

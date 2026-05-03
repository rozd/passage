import Foundation
import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration, .hooks))
struct `Account Hooks Integration Tests` {

    // MARK: - Test Error

    private struct TestPolicyError: AbortError {
        let status: HTTPResponseStatus = .forbidden
        let reason: String = "Blocked by hook"
    }

    // MARK: - Capture

    /// Records hook invocations across an integration test run.
    final class HookSpy: @unchecked Sendable {
        // Identifier captured from the form passed to willRegister.
        var willRegisterIdentifiers: [String] = []
        // Whether the user was already persisted in the store at the moment willRegister fired.
        var willRegisterSawUserInStore: [Bool] = []

        // User ids observed in each post-event callback.
        var didRegisterIds: [String] = []
        var willLoginIds: [String] = []
        var didLoginIds: [String] = []
        var willLogoutIds: [String] = []
        var didLogoutIds: [String] = []

        // When set, the corresponding `will*` hook throws this error.
        var willRegisterError: (any Error)?
        var willLoginError: (any Error)?
        var willLogoutError: (any Error)?

        func makeAccountHook() -> any Passage.Hooks.Account {
            _AccountHooksClosures.hook(
                willRegisterUser: { [self] form, request in
                    let resolved = try form.asIdentifier()
                    self.willRegisterIdentifiers.append(resolved.value)

                    // Snapshot the store at this point — if the hook truly fires
                    // before user creation this lookup returns nil.
                    let existing = try await request.store.users.find(byIdentifier: resolved)
                    self.willRegisterSawUserInStore.append(existing != nil)

                    if let error = self.willRegisterError {
                        throw error
                    }
                },
                didRegisterUser: { [self] user, _ in
                    self.didRegisterIds.append((try? user.requiredIdAsString) ?? "")
                },
                willLoginUser: { [self] user, _ in
                    self.willLoginIds.append((try? user.requiredIdAsString) ?? "")
                    if let error = self.willLoginError {
                        throw error
                    }
                },
                didLoginUser: { [self] user, _ in
                    self.didLoginIds.append((try? user.requiredIdAsString) ?? "")
                },
                willLogoutUser: { [self] user, _ in
                    self.willLogoutIds.append((try? user.requiredIdAsString) ?? "")
                    if let error = self.willLogoutError {
                        throw error
                    }
                },
                didLogoutUser: { [self] user, _ in
                    self.didLogoutIds.append((try? user.requiredIdAsString) ?? "")
                }
            )
        }
    }

    // MARK: - Configuration Helper

    /// Configures Passage with optional hooks installed.
    @Sendable private func configure(
        _ app: Application,
        hooks: Passage.Hooks = .init()
    ) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        // Sessions — required for the logout route to retain a logged-in user.
        app.middleware.use(app.sessions.middleware)

        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: nil,
            phoneDelivery: nil,
            federatedLogin: nil
        )

        let emptyJwks = """
        {"keys":[]}
        """

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
            )
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration,
            hooks: hooks
        )
    }

    // MARK: - Register Hook Wiring

    @Test
    func `willRegister fires before user is persisted`() async throws {
        let spy = HookSpy()
        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "user1",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            #expect(spy.willRegisterIdentifiers == ["user1"])
            #expect(spy.willRegisterSawUserInStore == [false])
        }
    }

    @Test
    func `didRegister fires with the newly created user`() async throws {
        let spy = HookSpy()
        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "user2",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            #expect(spy.didRegisterIds.count == 1)
            #expect(!spy.didRegisterIds[0].isEmpty)

            // The user the hook saw must match the one persisted in the store.
            let store = app.passage.storage.services.store
            let user = try await store.users.find(byIdentifier: .username("user2"))
            #expect(spy.didRegisterIds[0] == (try user!.requiredIdAsString))
        }
    }

    @Test
    func `Throwing willRegister aborts registration before user is persisted`() async throws {
        let spy = HookSpy()
        spy.willRegisterError = TestPolicyError()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "blocked",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            // willRegister fired once.
            #expect(spy.willRegisterIdentifiers == ["blocked"])
            // didRegister never fired because the flow aborted.
            #expect(spy.didRegisterIds.isEmpty)
            // No user was persisted.
            let store = app.passage.storage.services.store
            let user = try await store.users.find(byIdentifier: .username("blocked"))
            #expect(user == nil)
        }
    }

    // MARK: - Login Hook Wiring

    @Test
    func `willLogin and didLogin fire on successful login`() async throws {
        let spy = HookSpy()
        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            try await registerUsername(app: app, username: "loginok")

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "loginok",
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Both hooks fired once for the same user.
            #expect(spy.willLoginIds.count == 1)
            #expect(spy.didLoginIds.count == 1)
            #expect(spy.willLoginIds == spy.didLoginIds)
        }
    }

    @Test
    func `willLogin does not fire when password is invalid`() async throws {
        let spy = HookSpy()
        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            try await registerUsername(app: app, username: "wrongpass")

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "wrongpass",
                    "password": "not-the-password"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })

            #expect(spy.willLoginIds.isEmpty)
            #expect(spy.didLoginIds.isEmpty)
        }
    }

    @Test
    func `willLogin does not fire when user does not exist`() async throws {
        let spy = HookSpy()
        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "ghost",
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })

            #expect(spy.willLoginIds.isEmpty)
            #expect(spy.didLoginIds.isEmpty)
        }
    }

    @Test
    func `Throwing willLogin aborts login and didLogin never fires`() async throws {
        let spy = HookSpy()
        spy.willLoginError = TestPolicyError()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            try await registerUsername(app: app, username: "blocklogin")

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "blocklogin",
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            #expect(spy.willLoginIds.count == 1)
            #expect(spy.didLoginIds.isEmpty)
        }
    }

    // MARK: - Logout Hook Wiring

    @Test
    func `willLogout and didLogout fire when a user is logged in`() async throws {
        let spy = HookSpy()
        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            try await registerUsername(app: app, username: "logout-user")
            let token = try await loginAndGetAccessToken(app: app, username: "logout-user")

            try await app.testing().test(.POST, "auth/logout", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode([String: String]())
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            #expect(spy.willLogoutIds.count == 1)
            #expect(spy.didLogoutIds.count == 1)
            #expect(spy.willLogoutIds == spy.didLogoutIds)
        }
    }

    @Test
    func `Logout hooks do not fire when no user is authenticated`() async throws {
        let spy = HookSpy()
        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            // No bearer token attached — request has no authenticated user.
            try await app.testing().test(.POST, "auth/logout", beforeRequest: { req in
                try req.content.encode([String: String]())
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            #expect(spy.willLogoutIds.isEmpty)
            #expect(spy.didLogoutIds.isEmpty)
        }
    }

    @Test
    func `Throwing willLogout aborts logout and didLogout never fires`() async throws {
        let spy = HookSpy()
        spy.willLogoutError = TestPolicyError()

        try await withApp(configure: { app in
            try await self.configure(app, hooks: .init(account: spy.makeAccountHook()))
        }) { app in
            try await registerUsername(app: app, username: "logout-block")
            let token = try await loginAndGetAccessToken(app: app, username: "logout-block")

            try await app.testing().test(.POST, "auth/logout", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode([String: String]())
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })

            #expect(spy.willLogoutIds.count == 1)
            #expect(spy.didLogoutIds.isEmpty)
        }
    }

    // MARK: - Default Wiring (no hooks)

    @Test
    func `Default configure leaves hooks account nil`() async throws {
        try await withApp(configure: { app in
            try await self.configure(app)
        }) { app in
            #expect(app.passage.storage.hooks.account == nil)
        }
    }

    @Test
    func `Register works without hooks installed`() async throws {
        try await withApp(configure: { app in
            try await self.configure(app)
        }) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "no-hooks",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }
    }

    // MARK: - Test Helpers

    @Sendable private func registerUsername(
        app: Application,
        username: String,
        password: String = "password123"
    ) async throws {
        try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
            try req.content.encode([
                "username": username,
                "password": password,
                "confirmPassword": password
            ])
        }, afterResponse: { res async in
            #expect(res.status == .ok)
        })
    }

    @Sendable private func loginAndGetAccessToken(
        app: Application,
        username: String,
        password: String = "password123"
    ) async throws -> String {
        let captured = TokenCapture()
        try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
            try req.content.encode([
                "username": username,
                "password": password
            ])
        }, afterResponse: { res async throws in
            #expect(res.status == .ok)
            let auth = try res.content.decode(AuthUser.self)
            captured.token = auth.accessToken
        })
        return captured.token
    }

    private final class TokenCapture: @unchecked Sendable {
        var token: String = ""
    }
}

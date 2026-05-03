@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor

@Suite(.tags(.unit, .hooks))
struct `Hooks Struct Tests` {

    // MARK: - Namespace

    @Test
    func `Hooks struct is namespaced under Passage`() {
        let typeName = String(reflecting: Passage.Hooks.self)
        #expect(typeName.contains("Passage.Hooks"))
    }

    @Test
    func `Account protocol is namespaced under Passage Hooks`() {
        let typeName = String(reflecting: (any Passage.Hooks.Account).self)
        #expect(typeName.contains("Passage"))
        #expect(typeName.contains("Hooks"))
        #expect(typeName.contains("Account"))
    }

    // MARK: - Default Initializer

    @Test
    func `Default Hooks initializer leaves account nil`() {
        let hooks = Passage.Hooks()
        #expect(hooks.account == nil)
    }

    @Test
    func `Hooks initializer stores explicitly provided account`() {
        let custom = NoopAccountHook()
        let hooks = Passage.Hooks(account: custom)
        #expect(hooks.account != nil)
        #expect(hooks.account is NoopAccountHook)
    }

    // MARK: - Default Protocol Implementations

    @Test
    func `Default willRegister implementation does not throw`() async throws {
        let hook = NoopAccountHook()
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let form = Passage.DefaultRegisterForm(
            email: "user@example.com",
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )

        try await hook.willRegister(with: form, on: request)
    }

    @Test
    func `Default didRegister implementation completes without error`() async throws {
        let hook = NoopAccountHook()
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let user = Passage.OnlyForTest.InMemoryUser(
            id: "test-id",
            email: "user@example.com",
            phone: nil,
            username: nil,
            passwordHash: "hash",
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        await hook.didRegister(user: user, on: request)
    }

    @Test
    func `Default willLogin implementation does not throw`() async throws {
        let hook = NoopAccountHook()
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let user = Self.makeUser()

        try await hook.willLogin(user: user, on: request)
    }

    @Test
    func `Default didLogin implementation completes without error`() async throws {
        let hook = NoopAccountHook()
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let user = Self.makeUser()

        await hook.didLogin(user: user, on: request)
    }

    @Test
    func `Default willLogout implementation does not throw`() async throws {
        let hook = NoopAccountHook()
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let user = Self.makeUser()

        try await hook.willLogout(user: user, on: request)
    }

    @Test
    func `Default didLogout implementation completes without error`() async throws {
        let hook = NoopAccountHook()
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let user = Self.makeUser()

        await hook.didLogout(user: user, on: request)
    }

    // MARK: - Helpers

    private static func makeUser() -> Passage.OnlyForTest.InMemoryUser {
        Passage.OnlyForTest.InMemoryUser(
            id: "test-id",
            email: "user@example.com",
            phone: nil,
            username: nil,
            passwordHash: "hash",
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
    }
}

// MARK: - Minimal Conforming Type (relies on default implementations)

private struct NoopAccountHook: Passage.Hooks.Account {}

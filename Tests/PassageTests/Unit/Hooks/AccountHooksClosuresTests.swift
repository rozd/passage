@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor

@Suite(.tags(.unit, .hooks))
struct `Account Hooks Closures Tests` {

    // MARK: - Test Error

    private struct TestError: Error, Equatable {
        let tag: String
    }

    // MARK: - Sendable Capture

    private final class Capture: @unchecked Sendable {
        var willRegisterIdentifiers: [String] = []
        var didRegisterIds: [String] = []
        var willLoginIds: [String] = []
        var didLoginIds: [String] = []
        var willLogoutIds: [String] = []
        var didLogoutIds: [String] = []
    }

    // MARK: - Helpers

    private static func makeUser(id: String = "user-id") -> Passage.OnlyForTest.InMemoryUser {
        Passage.OnlyForTest.InMemoryUser(
            id: id,
            email: "user@example.com",
            phone: nil,
            username: nil,
            passwordHash: "hash",
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
    }

    private static func makeForm() -> Passage.DefaultRegisterForm {
        Passage.DefaultRegisterForm(
            email: "user@example.com",
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )
    }

    @Sendable private func makeApplication() async throws -> Application {
        try await Application.make(.testing)
    }

    // MARK: - Empty Factory

    @Test
    func `Empty closures factory does not throw on willRegister`() async throws {
        let hook = _AccountHooksClosures.hook()
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        try await hook.willRegister(with: Self.makeForm(), on: request)
    }

    @Test
    func `Empty closures factory does not throw on willLogin`() async throws {
        let hook = _AccountHooksClosures.hook()
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        try await hook.willLogin(user: Self.makeUser(), on: request)
    }

    @Test
    func `Empty closures factory does not throw on willLogout`() async throws {
        let hook = _AccountHooksClosures.hook()
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        try await hook.willLogout(user: Self.makeUser(), on: request)
    }

    @Test
    func `Empty closures factory completes silently on didRegister`() async throws {
        let hook = _AccountHooksClosures.hook()
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        await hook.didRegister(user: Self.makeUser(), on: request)
    }

    @Test
    func `Empty closures factory completes silently on didLogin`() async throws {
        let hook = _AccountHooksClosures.hook()
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        await hook.didLogin(user: Self.makeUser(), on: request)
    }

    @Test
    func `Empty closures factory completes silently on didLogout`() async throws {
        let hook = _AccountHooksClosures.hook()
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        await hook.didLogout(user: Self.makeUser(), on: request)
    }

    // MARK: - Closure Invocation

    @Test
    func `willRegister closure receives form and request`() async throws {
        let capture = Capture()
        let hook = _AccountHooksClosures.hook(
            willRegisterUser: { form, _ in
                capture.willRegisterIdentifiers.append(form.email ?? "?")
            }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        try await hook.willRegister(with: Self.makeForm(), on: request)

        #expect(capture.willRegisterIdentifiers == ["user@example.com"])
    }

    @Test
    func `didRegister closure receives created user`() async throws {
        let capture = Capture()
        let hook = _AccountHooksClosures.hook(
            didRegisterUser: { user, _ in
                capture.didRegisterIds.append((try? user.requiredIdAsString) ?? "")
            }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        await hook.didRegister(user: Self.makeUser(id: "abc"), on: request)

        #expect(capture.didRegisterIds == ["abc"])
    }

    @Test
    func `willLogin closure receives authenticated user`() async throws {
        let capture = Capture()
        let hook = _AccountHooksClosures.hook(
            willLoginUser: { user, _ in
                capture.willLoginIds.append((try? user.requiredIdAsString) ?? "")
            }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        try await hook.willLogin(user: Self.makeUser(id: "login-id"), on: request)

        #expect(capture.willLoginIds == ["login-id"])
    }

    @Test
    func `didLogin closure receives authenticated user`() async throws {
        let capture = Capture()
        let hook = _AccountHooksClosures.hook(
            didLoginUser: { user, _ in
                capture.didLoginIds.append((try? user.requiredIdAsString) ?? "")
            }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        await hook.didLogin(user: Self.makeUser(id: "did-login"), on: request)

        #expect(capture.didLoginIds == ["did-login"])
    }

    @Test
    func `willLogout closure receives user about to log out`() async throws {
        let capture = Capture()
        let hook = _AccountHooksClosures.hook(
            willLogoutUser: { user, _ in
                capture.willLogoutIds.append((try? user.requiredIdAsString) ?? "")
            }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        try await hook.willLogout(user: Self.makeUser(id: "out"), on: request)

        #expect(capture.willLogoutIds == ["out"])
    }

    @Test
    func `didLogout closure receives user that just logged out`() async throws {
        let capture = Capture()
        let hook = _AccountHooksClosures.hook(
            didLogoutUser: { user, _ in
                capture.didLogoutIds.append((try? user.requiredIdAsString) ?? "")
            }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        await hook.didLogout(user: Self.makeUser(id: "out-after"), on: request)

        #expect(capture.didLogoutIds == ["out-after"])
    }

    // MARK: - Error Propagation

    @Test
    func `willRegister propagates errors thrown by closure`() async throws {
        let hook = _AccountHooksClosures.hook(
            willRegisterUser: { _, _ in throw TestError(tag: "register") }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        await #expect(throws: TestError.self) {
            try await hook.willRegister(with: Self.makeForm(), on: request)
        }
    }

    @Test
    func `willLogin propagates errors thrown by closure`() async throws {
        let hook = _AccountHooksClosures.hook(
            willLoginUser: { _, _ in throw TestError(tag: "login") }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        await #expect(throws: TestError.self) {
            try await hook.willLogin(user: Self.makeUser(), on: request)
        }
    }

    @Test
    func `willLogout propagates errors thrown by closure`() async throws {
        let hook = _AccountHooksClosures.hook(
            willLogoutUser: { _, _ in throw TestError(tag: "logout") }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        await #expect(throws: TestError.self) {
            try await hook.willLogout(user: Self.makeUser(), on: request)
        }
    }

    // MARK: - Credential Issuance Hooks

    @Test
    func `Empty closures factory does not throw on willIssueCredential`() async throws {
        let hook = _AccountHooksClosures.hook()
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        let store = Passage.OnlyForTest.InMemoryStore()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: Self.makeUser(),
            sessionId: UUID(),
            store: store
        )

        try await hook.willIssueCredential(issuance, on: request)
    }

    @Test
    func `Empty closures factory completes silently on didIssueCredential`() async throws {
        let hook = _AccountHooksClosures.hook()
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        let store = Passage.OnlyForTest.InMemoryStore()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: Self.makeUser(),
            sessionId: UUID(),
            store: store
        )

        await hook.didIssueCredential(issuance, on: request)
    }

    @Test
    func `Empty closures factory returns false for isSessionRevoked`() async throws {
        let hook = _AccountHooksClosures.hook()
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        let result = await hook.isSessionRevoked(UUID(), on: request)
        #expect(result == false)
    }

    @Test
    func `willIssueCredential closure receives issuance`() async throws {
        final class IssuanceCapture: @unchecked Sendable {
            var issuance: CredentialIssuance?
        }
        let capture = IssuanceCapture()

        let hook = _AccountHooksClosures.hook(
            willIssueCredential: { issuance, _ in
                capture.issuance = issuance
            }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        let store = Passage.OnlyForTest.InMemoryStore()
        let sessionId = UUID()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: Self.makeUser(id: "issuance-user"),
            sessionId: sessionId,
            store: store
        )

        try await hook.willIssueCredential(issuance, on: request)

        #expect(capture.issuance?.sessionId == sessionId)
        #expect((try? capture.issuance?.user.requiredIdAsString) == "issuance-user")
    }

    @Test
    func `didIssueCredential closure receives issuance`() async throws {
        final class IssuanceCapture: @unchecked Sendable {
            var issuance: CredentialIssuance?
        }
        let capture = IssuanceCapture()

        let hook = _AccountHooksClosures.hook(
            didIssueCredential: { issuance, _ in
                capture.issuance = issuance
            }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        let store = Passage.OnlyForTest.InMemoryStore()
        let sessionId = UUID()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: Self.makeUser(id: "did-issuance-user"),
            sessionId: sessionId,
            store: store
        )

        await hook.didIssueCredential(issuance, on: request)

        #expect(capture.issuance?.sessionId == sessionId)
    }

    @Test
    func `isSessionRevoked closure returns true when set to true`() async throws {
        let hook = _AccountHooksClosures.hook(
            isSessionRevoked: { _, _ in true }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        let sessionId = UUID()
        let result = await hook.isSessionRevoked(sessionId, on: request)
        #expect(result == true)
    }

    @Test
    func `isSessionRevoked closure returns false when set to false`() async throws {
        let hook = _AccountHooksClosures.hook(
            isSessionRevoked: { _, _ in false }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        let sessionId = UUID()
        let result = await hook.isSessionRevoked(sessionId, on: request)
        #expect(result == false)
    }

    @Test
    func `willIssueCredential propagates errors thrown by closure`() async throws {
        let hook = _AccountHooksClosures.hook(
            willIssueCredential: { _, _ in throw TestError(tag: "issuance") }
        )
        let app = try await makeApplication()
        defer { Task { try await app.asyncShutdown() } }
        let request = Request(application: app, on: app.eventLoopGroup.next())

        let store = Passage.OnlyForTest.InMemoryStore()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: Self.makeUser(),
            sessionId: UUID(),
            store: store
        )

        await #expect(throws: TestError.self) {
            try await hook.willIssueCredential(issuance, on: request)
        }
    }

    // MARK: - Conformance & Type Identity

    @Test
    func `closures factory returns a Passage Hooks Account`() {
        // The explicit type annotation pins the factory's opaque return type to
        // `any Passage.Hooks.Account`, proving the conformance at compile time.
        let _: any Passage.Hooks.Account = _AccountHooksClosures.hook()
    }

    @Test
    func `closures factory result is storable on Passage Hooks`() {
        let hooks = Passage.Hooks(account: _AccountHooksClosures.hook())
        #expect(hooks.account != nil)
    }
}

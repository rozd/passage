@testable import Passage
@testable import PassageOnlyForTest
import Foundation
import Testing

@Suite(.tags(.unit))
struct `Credential Issuance Tests` {

    private struct MockUser: User {
        typealias Id = UUID
        var id: UUID?
        var email: String?
        var phone: String?
        var username: String?
        var passwordHash: String?
        var isAnonymous: Bool
        var isEmailVerified: Bool
        var isPhoneVerified: Bool

        var sessionID: String {
            guard let id = id else { fatalError("MockUser must have an ID") }
            return id.uuidString
        }
    }

    private func makeUser() -> MockUser {
        MockUser(
            id: UUID(),
            email: "user@example.com",
            phone: nil,
            username: nil,
            passwordHash: "hash",
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
    }

    @Test
    func `init stores kind`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let kind = CredentialIssuance.Kind.bearer
        let issuance = CredentialIssuance(
            kind: kind,
            origin: .login,
            user: makeUser(),
            sessionId: UUID(),
            store: store
        )

        #expect(issuance.kind == kind)
    }

    @Test
    func `init stores origin`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let origin = CredentialIssuance.Origin.login
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: origin,
            user: makeUser(),
            sessionId: UUID(),
            store: store
        )

        #expect(issuance.origin == origin)
    }

    @Test
    func `init stores user`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let user = makeUser()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: user,
            sessionId: UUID(),
            store: store
        )

        #expect((try? issuance.user.requiredIdAsString) == (try? user.requiredIdAsString))
    }

    @Test
    func `init stores sessionId`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let sessionId = UUID()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: makeUser(),
            sessionId: sessionId,
            store: store
        )

        #expect(issuance.sessionId == sessionId)
    }

    @Test
    func `init optional accessToken defaults to nil`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: makeUser(),
            sessionId: UUID(),
            store: store
        )

        #expect(issuance.accessToken == nil)
    }

    @Test
    func `init optional accessToken stores provided value`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let token = "test-token"
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: makeUser(),
            sessionId: UUID(),
            accessToken: token,
            store: store
        )

        #expect(issuance.accessToken == token)
    }

    @Test
    func `init optional accessTokenExpiresAt defaults to nil`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: makeUser(),
            sessionId: UUID(),
            store: store
        )

        #expect(issuance.accessTokenExpiresAt == nil)
    }

    @Test
    func `init optional accessTokenExpiresAt stores provided value`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let expiresAt = Date()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: makeUser(),
            sessionId: UUID(),
            accessTokenExpiresAt: expiresAt,
            store: store
        )

        #expect(issuance.accessTokenExpiresAt == expiresAt)
    }

    @Test
    func `init optional refreshTokenExpiresAt defaults to nil`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: makeUser(),
            sessionId: UUID(),
            store: store
        )

        #expect(issuance.refreshTokenExpiresAt == nil)
    }

    @Test
    func `init optional refreshTokenExpiresAt stores provided value`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let expiresAt = Date()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: makeUser(),
            sessionId: UUID(),
            refreshTokenExpiresAt: expiresAt,
            store: store
        )

        #expect(issuance.refreshTokenExpiresAt == expiresAt)
    }

    @Test
    func `init revokedSessionIds defaults to empty array`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: makeUser(),
            sessionId: UUID(),
            store: store
        )

        #expect(issuance.revokedSessionIds == [])
    }

    @Test
    func `init revokedSessionIds stores provided value`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let ids = [UUID(), UUID()]
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: makeUser(),
            sessionId: UUID(),
            revokedSessionIds: ids,
            store: store
        )

        #expect(issuance.revokedSessionIds == ids)
    }

    @Test
    func `Kind bearer and browser are equatable and distinct`() {
        #expect(CredentialIssuance.Kind.bearer == .bearer)
        #expect(CredentialIssuance.Kind.browser == .browser)
        #expect(CredentialIssuance.Kind.bearer != .browser)
    }

    @Test
    func `Origin login and magicLink are distinct`() {
        #expect(CredentialIssuance.Origin.login == .login)
        #expect(CredentialIssuance.Origin.magicLink == .magicLink)
        #expect(CredentialIssuance.Origin.login != .magicLink)
    }

    @Test
    func `Origin refresh and exchange are distinct`() {
        #expect(CredentialIssuance.Origin.refresh == .refresh)
        #expect(CredentialIssuance.Origin.exchange == .exchange)
        #expect(CredentialIssuance.Origin.refresh != .exchange)
    }

    @Test
    func `Origin federatedLogin and passkey are distinct`() {
        #expect(CredentialIssuance.Origin.federatedLogin == .federatedLogin)
        #expect(CredentialIssuance.Origin.passkey == .passkey)
        #expect(CredentialIssuance.Origin.federatedLogin != .passkey)
    }

    @Test
    func `Origin accountLinking is distinct from others`() {
        #expect(CredentialIssuance.Origin.accountLinking == .accountLinking)
        #expect(CredentialIssuance.Origin.accountLinking != .login)
        #expect(CredentialIssuance.Origin.accountLinking != .magicLink)
    }

    @Test
    func `all seven Origin cases are distinct`() {
        let origins: [CredentialIssuance.Origin] = [
            .login, .magicLink, .refresh, .exchange, .federatedLogin, .passkey, .accountLinking
        ]
        let uniqueOrigins = Set(origins.map { "\($0)" })
        #expect(uniqueOrigins.count == 7)
    }

    @Test
    func `is Sendable`() {
        let store = Passage.OnlyForTest.InMemoryStore()
        let issuance = CredentialIssuance(
            kind: .bearer,
            origin: .login,
            user: makeUser(),
            sessionId: UUID(),
            store: store
        )
        let _: any Sendable = issuance
    }
}

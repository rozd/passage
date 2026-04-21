import Testing
import Foundation
@testable import Passage

@Suite
struct `Store Protocols Tests` {

    // MARK: - Mock Implementations

    struct MockUser: User {
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
            guard let id = id else {
                fatalError("MockUser must have an ID for session authentication")
            }
            return id.uuidString
        }
    }

    struct MockRefreshToken: RefreshToken {
        typealias Id = UUID
        typealias AssociatedUser = MockUser
        var id: UUID?
        var user: MockUser
        var tokenHash: String
        var expiresAt: Date
        var revokedAt: Date?
        var replacedBy: UUID?
    }

    struct MockEmailVerificationCode: EmailVerificationCode {
        typealias AssociatedUser = MockUser
        var user: MockUser
        var codeHash: String
        var expiresAt: Date
        var failedAttempts: Int
        var email: String
    }

    struct MockPhoneVerificationCode: PhoneVerificationCode {
        typealias AssociatedUser = MockUser
        var user: MockUser
        var codeHash: String
        var expiresAt: Date
        var failedAttempts: Int
        var phone: String
    }

    struct MockEmailPasswordResetCode: EmailPasswordResetCode {
        typealias AssociatedUser = MockUser
        var user: MockUser
        var codeHash: String
        var expiresAt: Date
        var failedAttempts: Int
        var email: String
    }

    struct MockPhonePasswordResetCode: PhonePasswordResetCode {
        typealias AssociatedUser = MockUser
        var user: MockUser
        var codeHash: String
        var expiresAt: Date
        var failedAttempts: Int
        var phone: String
    }

    // MARK: - UserStore Protocol Tests

    struct MockUserStore: Passage.UserStore {

        typealias ConcreateUser = MockUser
        var userType: MockUser.Type { MockUser.self }

        func create(identifier: Identifier, with credential: Credential?) async throws -> any User {
            MockUser(
                id: UUID(),
                email: identifier.kind == .email ? identifier.value : nil,
                phone: identifier.kind == .phone ? identifier.value : nil,
                username: identifier.kind == .username ? identifier.value : nil,
                passwordHash: credential?.secret,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            )
        }

        func addIdentifier(
            _ identifier: Identifier,
            to user: any User,
            with credential: Credential?
        ) async throws {
            // Method signature test
        }

        func find(byId id: String) async throws -> (any User)? {
            nil
        }

        func find(byIdentifier identifier: Identifier) async throws -> (any User)? {
            nil
        }

        func markEmailVerified(for user: any User) async throws {
            // Method signature test
        }

        func markPhoneVerified(for user: any User) async throws {
            // Method signature test
        }

        func setPassword(for user: any User, passwordHash: String) async throws {
            // Method signature test
        }

        func createWithEmail(_ email: String, verified: Bool) async throws -> any User {
            MockUser(id: UUID(), email: email, phone: nil, username: nil, passwordHash: nil, isAnonymous: false, isEmailVerified: verified, isPhoneVerified: false)
        }

        func createWithPhone(_ phone: String, verified: Bool) async throws -> any User {
            MockUser(id: UUID(), email: nil, phone: phone, username: nil, passwordHash: nil, isAnonymous: false, isEmailVerified: false, isPhoneVerified: verified)
        }
    }

    @Test
    func `UserStore protocol can be implemented`() {
        let store: any Passage.UserStore = MockUserStore()
        #expect(store.userType is MockUser.Type)
    }

    @Test
    func `UserStore protocol conforms to Sendable`() {
        let store: any Sendable = MockUserStore()
        #expect(store is MockUserStore)
    }

    // MARK: - TokenStore Protocol Tests

    struct MockTokenStore: Passage.TokenStore {
        func createRefreshToken(
            for user: any User,
            tokenHash hash: String,
            expiresAt: Date
        ) async throws -> any RefreshToken {
            MockRefreshToken(
                id: UUID(),
                user: user as! MockUser,
                tokenHash: hash,
                expiresAt: expiresAt,
                revokedAt: nil,
                replacedBy: nil
            )
        }

        func createRefreshToken(
            for user: any User,
            tokenHash hash: String,
            expiresAt: Date,
            replacing tokenToReplace: (any RefreshToken)?
        ) async throws -> any RefreshToken {
            MockRefreshToken(
                id: UUID(),
                user: user as! MockUser,
                tokenHash: hash,
                expiresAt: expiresAt,
                revokedAt: nil,
                replacedBy: tokenToReplace?.id as? UUID
            )
        }

        func find(refreshTokenHash hash: String) async throws -> (any RefreshToken)? {
            nil
        }

        func revokeRefreshToken(for user: any User) async throws {
            // Method signature test
        }

        func revokeRefreshToken(withHash hash: String) async throws {
            // Method signature test
        }

        func revoke(refreshTokenFamilyStartingFrom token: any RefreshToken) async throws {
            // Method signature test
        }
    }

    @Test
    func `TokenStore protocol can be implemented`() {
        let store: any Passage.TokenStore = MockTokenStore()
        #expect(store is MockTokenStore)
    }

    @Test
    func `TokenStore protocol conforms to Sendable`() {
        let store: any Sendable = MockTokenStore()
        #expect(store is MockTokenStore)
    }

    // MARK: - VerificationCodeStore Protocol Tests

    struct MockVerificationCodeStore: Passage.VerificationCodeStore {
        func createEmailCode(
            for user: any User,
            email: String,
            codeHash: String,
            expiresAt: Date
        ) async throws -> any EmailVerificationCode {
            MockEmailVerificationCode(
                user: user as! MockUser,
                codeHash: codeHash,
                expiresAt: expiresAt,
                failedAttempts: 0,
                email: email
            )
        }

        func findEmailCode(
            forEmail email: String,
            codeHash: String
        ) async throws -> (any EmailVerificationCode)? {
            nil
        }

        func invalidateEmailCodes(forEmail email: String) async throws {
            // Method signature test
        }

        func incrementFailedAttempts(for code: any EmailVerificationCode) async throws {
            // Method signature test
        }

        func createPhoneCode(
            for user: any User,
            phone: String,
            codeHash: String,
            expiresAt: Date
        ) async throws -> any PhoneVerificationCode {
            MockPhoneVerificationCode(
                user: user as! MockUser,
                codeHash: codeHash,
                expiresAt: expiresAt,
                failedAttempts: 0,
                phone: phone
            )
        }

        func findPhoneCode(
            forPhone phone: String,
            codeHash: String
        ) async throws -> (any PhoneVerificationCode)? {
            nil
        }

        func invalidatePhoneCodes(forPhone phone: String) async throws {
            // Method signature test
        }

        func incrementFailedAttempts(for code: any PhoneVerificationCode) async throws {
            // Method signature test
        }
    }

    @Test
    func `VerificationCodeStore protocol can be implemented`() {
        let store: any Passage.VerificationCodeStore = MockVerificationCodeStore()
        #expect(store is MockVerificationCodeStore)
    }

    @Test
    func `VerificationCodeStore protocol conforms to Sendable`() {
        let store: any Sendable = MockVerificationCodeStore()
        #expect(store is MockVerificationCodeStore)
    }

    // MARK: - RestorationCodeStore Protocol Tests

    struct MockRestorationCodeStore: Passage.RestorationCodeStore {
        func createPasswordResetCode(
            for user: any User,
            email: String,
            codeHash: String,
            expiresAt: Date
        ) async throws -> any EmailPasswordResetCode {
            MockEmailPasswordResetCode(
                user: user as! MockUser,
                codeHash: codeHash,
                expiresAt: expiresAt,
                failedAttempts: 0,
                email: email
            )
        }

        func findPasswordResetCode(
            forEmail email: String,
            codeHash: String
        ) async throws -> (any EmailPasswordResetCode)? {
            nil
        }

        func invalidatePasswordResetCodes(forEmail email: String) async throws {
            // Method signature test
        }

        func incrementFailedAttempts(for code: any EmailPasswordResetCode) async throws {
            // Method signature test
        }

        func createPasswordResetCode(
            for user: any User,
            phone: String,
            codeHash: String,
            expiresAt: Date
        ) async throws -> any PhonePasswordResetCode {
            MockPhonePasswordResetCode(
                user: user as! MockUser,
                codeHash: codeHash,
                expiresAt: expiresAt,
                failedAttempts: 0,
                phone: phone
            )
        }

        func findPasswordResetCode(
            forPhone phone: String,
            codeHash: String
        ) async throws -> (any PhonePasswordResetCode)? {
            nil
        }

        func invalidatePasswordResetCodes(forPhone phone: String) async throws {
            // Method signature test
        }

        func incrementFailedAttempts(for code: any PhonePasswordResetCode) async throws {
            // Method signature test
        }
    }

    @Test
    func `RestorationCodeStore protocol can be implemented`() {
        let store: any Passage.RestorationCodeStore = MockRestorationCodeStore()
        #expect(store is MockRestorationCodeStore)
    }

    @Test
    func `RestorationCodeStore protocol conforms to Sendable`() {
        let store: any Sendable = MockRestorationCodeStore()
        #expect(store is MockRestorationCodeStore)
    }

    // MARK: - MagicLinkTokenStore Protocol Tests

    struct MockMagicLinkToken: MagicLinkToken {
        typealias AssociatedUser = MockUser
        var user: MockUser?
        var identifier: Identifier
        var tokenHash: String
        var sessionTokenHash: String?
        var expiresAt: Date
        var failedAttempts: Int
    }

    struct MockMagicLinkTokenStore: Passage.MagicLinkTokenStore {
        func createEmailMagicLink(for user: (any User)?, identifier: Identifier, tokenHash: String, sessionTokenHash: String?, expiresAt: Date) async throws -> any MagicLinkToken {
            MockMagicLinkToken(user: user as? MockUser, identifier: identifier, tokenHash: tokenHash, sessionTokenHash: sessionTokenHash, expiresAt: expiresAt, failedAttempts: 0)
        }
        func findEmailMagicLink(tokenHash: String) async throws -> (any MagicLinkToken)? { nil }
        func invalidateEmailMagicLinks(for identifier: Identifier) async throws {}
        func incrementFailedAttempts(for magicLink: any MagicLinkToken) async throws {}
    }

    @Test
    func `MagicLinkTokenStore protocol can be implemented`() {
        let store: any Passage.MagicLinkTokenStore = MockMagicLinkTokenStore()
        #expect(store is MockMagicLinkTokenStore)
    }

    @Test
    func `MagicLinkTokenStore protocol conforms to Sendable`() {
        let store: any Sendable = MockMagicLinkTokenStore()
        #expect(store is MockMagicLinkTokenStore)
    }

    // MARK: - ExchangeTokenStore Protocol Tests

    struct MockExchangeToken: ExchangeToken {
        typealias Id = UUID
        typealias AssociatedUser = MockUser
        var id: UUID?
        var user: MockUser
        var tokenHash: String
        var expiresAt: Date
        var consumedAt: Date?
        var createdAt: Date?
    }

    struct MockExchangeTokenStore: Passage.ExchangeTokenStore {
        @discardableResult
        func createExchangeToken(
            for user: any User,
            tokenHash: String,
            expiresAt: Date
        ) async throws -> any ExchangeToken {
            MockExchangeToken(
                id: UUID(),
                user: user as! MockUser,
                tokenHash: tokenHash,
                expiresAt: expiresAt,
                consumedAt: nil,
                createdAt: Date()
            )
        }

        func find(exchangeTokenHash hash: String) async throws -> (any ExchangeToken)? {
            nil
        }

        func consume(exchangeToken: any ExchangeToken) async throws {
            // Method signature test
        }

        func cleanupExpiredTokens(before date: Date) async throws {
            // Method signature test
        }
    }

    @Test
    func `ExchangeTokenStore protocol can be implemented`() {
        let store: any Passage.ExchangeTokenStore = MockExchangeTokenStore()
        #expect(store is MockExchangeTokenStore)
    }

    @Test
    func `ExchangeTokenStore protocol conforms to Sendable`() {
        let store: any Sendable = MockExchangeTokenStore()
        #expect(store is MockExchangeTokenStore)
    }

    // MARK: - Store Protocol Tests

    struct MockStore: Passage.Store {
        var users: any Passage.UserStore { MockUserStore() }
        var tokens: any Passage.TokenStore { MockTokenStore() }
        var verificationCodes: any Passage.VerificationCodeStore { MockVerificationCodeStore() }
        var restorationCodes: any Passage.RestorationCodeStore { MockRestorationCodeStore() }
        var magicLinkTokens: any Passage.MagicLinkTokenStore { MockMagicLinkTokenStore() }
        var exchangeTokens: any Passage.ExchangeTokenStore { MockExchangeTokenStore() }
    }

    @Test
    func `Store protocol can be implemented`() {
        let store: any Passage.Store = MockStore()
        #expect(store is MockStore)
    }

    @Test
    func `Store protocol conforms to Sendable`() {
        let store: any Sendable = MockStore()
        #expect(store is MockStore)
    }

    @Test
    func `Store protocol provides access to all sub-stores`() {
        let store: any Passage.Store = MockStore()

        #expect(store.users is MockUserStore)
        #expect(store.tokens is MockTokenStore)
        #expect(store.verificationCodes is MockVerificationCodeStore)
        #expect(store.restorationCodes is MockRestorationCodeStore)
        #expect(store.magicLinkTokens is MockMagicLinkTokenStore)
        #expect(store.exchangeTokens is MockExchangeTokenStore)
    }
}

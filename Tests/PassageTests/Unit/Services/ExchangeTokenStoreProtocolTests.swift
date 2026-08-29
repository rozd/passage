import Testing
import Foundation
@testable import Passage

@Suite(.tags(.unit))
struct `ExchangeTokenStore Protocol Tests` {

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
        private var tokens: [String: MockExchangeToken] = [:]

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
            tokens[hash]
        }

        func consume(exchangeToken: any ExchangeToken) async throws {
            // Method signature test
        }

        func cleanupExpiredTokens(before date: Date) async throws {
            // Method signature test
        }
    }

    // MARK: - Helper

    private func createMockUser() -> MockUser {
        MockUser(
            id: UUID(),
            email: "test@example.com",
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
    }

    // MARK: - Protocol Conformance Tests

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

    // MARK: - Method Signature Tests

    @Test
    func `createExchangeToken returns ExchangeToken`() async throws {
        let store = MockExchangeTokenStore()
        let user = createMockUser()

        let token = try await store.createExchangeToken(
            for: user,
            tokenHash: "test-hash",
            expiresAt: Date().addingTimeInterval(60)
        )

        #expect(token is MockExchangeToken)
        #expect(token.tokenHash == "test-hash")
    }

    @Test
    func `createExchangeToken sets correct user`() async throws {
        let store = MockExchangeTokenStore()
        let user = createMockUser()

        let token = try await store.createExchangeToken(
            for: user,
            tokenHash: "test-hash",
            expiresAt: Date().addingTimeInterval(60)
        )

        #expect(token.user.id?.description == user.id?.description)
    }

    @Test
    func `createExchangeToken sets correct expiration`() async throws {
        let store = MockExchangeTokenStore()
        let user = createMockUser()
        let expiresAt = Date().addingTimeInterval(60)

        let token = try await store.createExchangeToken(
            for: user,
            tokenHash: "test-hash",
            expiresAt: expiresAt
        )

        #expect(token.expiresAt == expiresAt)
    }

    @Test
    func `createExchangeToken creates unconsumed token`() async throws {
        let store = MockExchangeTokenStore()
        let user = createMockUser()

        let token = try await store.createExchangeToken(
            for: user,
            tokenHash: "test-hash",
            expiresAt: Date().addingTimeInterval(60)
        )

        #expect(token.consumedAt == nil)
        #expect(token.isConsumed == false)
    }

    @Test
    func `createExchangeToken creates valid token`() async throws {
        let store = MockExchangeTokenStore()
        let user = createMockUser()

        let token = try await store.createExchangeToken(
            for: user,
            tokenHash: "test-hash",
            expiresAt: Date().addingTimeInterval(60)
        )

        #expect(token.isValid == true)
    }

    @Test
    func `find returns nil for non-existent hash`() async throws {
        let store = MockExchangeTokenStore()

        let token = try await store.find(exchangeTokenHash: "non-existent-hash")

        #expect(token == nil)
    }

    // MARK: - Discardable Result Test

    @Test
    func `createExchangeToken is discardable`() async throws {
        let store = MockExchangeTokenStore()
        let user = createMockUser()

        // Should compile without warning when result is discarded
        try await store.createExchangeToken(
            for: user,
            tokenHash: "test-hash",
            expiresAt: Date().addingTimeInterval(60)
        )

        // If we get here without error, the discardable result works
        #expect(Bool(true))
    }

    // MARK: - Integration with Store Protocol

    @Test
    func `Store protocol includes exchangeTokens property`() {
        // This is a compile-time test - if Store protocol doesn't include
        // exchangeTokens, this code won't compile
        struct TestStore: Passage.Store {
            var users: any Passage.UserStore { fatalError() }
            var tokens: any Passage.TokenStore { fatalError() }
            var verificationCodes: any Passage.VerificationCodeStore { fatalError() }
            var restorationCodes: any Passage.RestorationCodeStore { fatalError() }
            var magicLinkTokens: any Passage.MagicLinkTokenStore { fatalError() }
            var exchangeTokens: any Passage.ExchangeTokenStore { MockExchangeTokenStore() }
            func transaction<T: Sendable>(_ body: @Sendable (any Passage.Store) async throws -> T) async throws -> T {
                try await body(self)
            }
        }

        let store: any Passage.Store = TestStore()
        #expect(store.exchangeTokens is MockExchangeTokenStore)
    }
}

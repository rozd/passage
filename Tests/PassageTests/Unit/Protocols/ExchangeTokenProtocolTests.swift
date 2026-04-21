import Testing
import Foundation
@testable import Passage

@Suite(.tags(.unit))
struct `ExchangeToken Protocol Tests` {

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

    // MARK: - Helper to create mock user

    private func createMockUser() -> MockUser {
        MockUser(
            id: UUID(),
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
    }

    // MARK: - isExpired Tests

    @Test
    func `ExchangeToken isExpired returns true when expired`() {
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(-60), // expired 1 minute ago
            consumedAt: nil,
            createdAt: Date()
        )

        #expect(token.isExpired == true)
    }

    @Test
    func `ExchangeToken isExpired returns false when not expired`() {
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(60), // expires in 1 minute
            consumedAt: nil,
            createdAt: Date()
        )

        #expect(token.isExpired == false)
    }

    @Test
    func `ExchangeToken isExpired returns true when exactly at expiration time`() {
        // Token that expired a tiny amount of time ago
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(-0.001),
            consumedAt: nil,
            createdAt: Date()
        )

        #expect(token.isExpired == true)
    }

    // MARK: - isConsumed Tests

    @Test
    func `ExchangeToken isConsumed returns true when consumed`() {
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(60),
            consumedAt: Date(), // has been consumed
            createdAt: Date()
        )

        #expect(token.isConsumed == true)
    }

    @Test
    func `ExchangeToken isConsumed returns false when not consumed`() {
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(60),
            consumedAt: nil, // not consumed
            createdAt: Date()
        )

        #expect(token.isConsumed == false)
    }

    @Test
    func `ExchangeToken isConsumed with past consumption time`() {
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(60),
            consumedAt: Date().addingTimeInterval(-3600), // consumed 1 hour ago
            createdAt: Date().addingTimeInterval(-7200)
        )

        #expect(token.isConsumed == true)
    }

    // MARK: - isValid Tests

    @Test
    func `ExchangeToken isValid returns true when not expired and not consumed`() {
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(60), // not expired
            consumedAt: nil, // not consumed
            createdAt: Date()
        )

        #expect(token.isValid == true)
    }

    @Test
    func `ExchangeToken isValid returns false when expired`() {
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(-60), // expired
            consumedAt: nil, // not consumed
            createdAt: Date()
        )

        #expect(token.isValid == false)
    }

    @Test
    func `ExchangeToken isValid returns false when consumed`() {
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(60), // not expired
            consumedAt: Date(), // consumed
            createdAt: Date()
        )

        #expect(token.isValid == false)
    }

    @Test
    func `ExchangeToken isValid returns false when both expired and consumed`() {
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(-60), // expired
            consumedAt: Date(), // consumed
            createdAt: Date()
        )

        #expect(token.isValid == false)
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `MockExchangeToken conforms to ExchangeToken protocol`() {
        let token: any ExchangeToken = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date(),
            consumedAt: nil,
            createdAt: Date()
        )
        #expect(token is MockExchangeToken)
    }

    @Test
    func `ExchangeToken protocol conforms to Sendable`() {
        let token: any Sendable = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date(),
            consumedAt: nil,
            createdAt: Date()
        )
        #expect(token is MockExchangeToken)
    }

    // MARK: - Properties Tests

    @Test
    func `ExchangeToken stores tokenHash correctly`() {
        let hash = "abc123hash456"
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: hash,
            expiresAt: Date(),
            consumedAt: nil,
            createdAt: Date()
        )

        #expect(token.tokenHash == hash)
    }

    @Test
    func `ExchangeToken stores user reference`() {
        let userId = UUID()
        let user = MockUser(
            id: userId,
            email: "test@example.com",
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
        let token = MockExchangeToken(
            id: UUID(),
            user: user,
            tokenHash: "hash",
            expiresAt: Date(),
            consumedAt: nil,
            createdAt: Date()
        )

        #expect(token.user.id == userId)
        #expect(token.user.email == "test@example.com")
    }

    @Test
    func `ExchangeToken stores id correctly`() {
        let tokenId = UUID()
        let token = MockExchangeToken(
            id: tokenId,
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date(),
            consumedAt: nil,
            createdAt: Date()
        )

        #expect(token.id == tokenId)
    }

    @Test
    func `ExchangeToken with nil id`() {
        let token = MockExchangeToken(
            id: nil,
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date(),
            consumedAt: nil,
            createdAt: Date()
        )

        #expect(token.id == nil)
    }

    @Test
    func `ExchangeToken stores createdAt correctly`() {
        let createdAt = Date().addingTimeInterval(-30)
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(30),
            consumedAt: nil,
            createdAt: createdAt
        )

        #expect(token.createdAt == createdAt)
    }

    @Test
    func `ExchangeToken with nil createdAt`() {
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date(),
            consumedAt: nil,
            createdAt: nil
        )

        #expect(token.createdAt == nil)
    }

    // MARK: - Short TTL Behavior Tests

    @Test
    func `ExchangeToken with typical 60-second TTL`() {
        let createdAt = Date()
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: createdAt.addingTimeInterval(60), // 60 seconds
            consumedAt: nil,
            createdAt: createdAt
        )

        #expect(token.isValid == true)
        #expect(token.isExpired == false)
        #expect(token.isConsumed == false)
    }

    @Test
    func `ExchangeToken expired after short TTL`() {
        let createdAt = Date().addingTimeInterval(-120) // created 2 minutes ago
        let token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: createdAt.addingTimeInterval(60), // expired 1 minute ago
            consumedAt: nil,
            createdAt: createdAt
        )

        #expect(token.isValid == false)
        #expect(token.isExpired == true)
    }

    // MARK: - Single-Use Behavior Tests

    @Test
    func `ExchangeToken becomes invalid after consumption`() {
        // Simulate consumption by creating a token with consumedAt set
        var token = MockExchangeToken(
            id: UUID(),
            user: createMockUser(),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(60),
            consumedAt: nil,
            createdAt: Date()
        )

        // Before consumption
        #expect(token.isValid == true)
        #expect(token.isConsumed == false)

        // Simulate consumption
        token.consumedAt = Date()

        // After consumption
        #expect(token.isValid == false)
        #expect(token.isConsumed == true)
    }
}

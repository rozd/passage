import Testing
import Foundation
@testable import Passage

@Suite
struct `RefreshToken Protocol Tests` {

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

    // MARK: - isExpired Tests

    @Test
    func `RefreshToken isExpired returns true when expired`() {
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(-3600), // expired 1 hour ago
            revokedAt: nil,
            replacedBy: nil
        )

        #expect(token.isExpired == true)
    }

    @Test
    func `RefreshToken isExpired returns false when not expired`() {
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(3600), // expires in 1 hour
            revokedAt: nil,
            replacedBy: nil
        )

        #expect(token.isExpired == false)
    }

    // MARK: - isRevoked Tests

    @Test
    func `RefreshToken isRevoked returns true when revoked`() {
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(3600),
            revokedAt: Date(),
            replacedBy: nil
        )

        #expect(token.isRevoked == true)
    }

    @Test
    func `RefreshToken isRevoked returns false when not revoked`() {
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(3600),
            revokedAt: nil,
            replacedBy: nil
        )

        #expect(token.isRevoked == false)
    }

    // MARK: - isValid Tests

    @Test
    func `RefreshToken isValid returns true when not expired and not revoked`() {
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(3600),
            revokedAt: nil,
            replacedBy: nil
        )

        #expect(token.isValid == true)
    }

    @Test
    func `RefreshToken isValid returns false when expired`() {
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(-3600),
            revokedAt: nil,
            replacedBy: nil
        )

        #expect(token.isValid == false)
    }

    @Test
    func `RefreshToken isValid returns false when revoked`() {
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(3600),
            revokedAt: Date(),
            replacedBy: nil
        )

        #expect(token.isValid == false)
    }

    @Test
    func `RefreshToken isValid returns false when both expired and revoked`() {
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(-3600),
            revokedAt: Date(),
            replacedBy: nil
        )

        #expect(token.isValid == false)
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `MockRefreshToken conforms to RefreshToken protocol`() {
        let token: any RefreshToken = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date(),
            revokedAt: nil,
            replacedBy: nil
        )
        #expect(token is MockRefreshToken)
    }

    @Test
    func `RefreshToken protocol conforms to Sendable`() {
        let token: any Sendable = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date(),
            revokedAt: nil,
            replacedBy: nil
        )
        #expect(token is MockRefreshToken)
    }

    // MARK: - Token Rotation Tests

    @Test
    func `RefreshToken with replacedBy set`() {
        let newTokenId = UUID()
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(3600),
            revokedAt: nil,
            replacedBy: newTokenId
        )

        #expect(token.replacedBy == newTokenId)
    }

    @Test
    func `RefreshToken without replacedBy`() {
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: "hash",
            expiresAt: Date().addingTimeInterval(3600),
            revokedAt: nil,
            replacedBy: nil
        )

        #expect(token.replacedBy == nil)
    }

    // MARK: - Properties Tests

    @Test
    func `RefreshToken stores tokenHash correctly`() {
        let hash = "abc123hash456"
        let token = MockRefreshToken(
            id: UUID(),
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            tokenHash: hash,
            expiresAt: Date(),
            revokedAt: nil,
            replacedBy: nil
        )

        #expect(token.tokenHash == hash)
    }

    @Test
    func `RefreshToken stores user reference`() {
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
        let token = MockRefreshToken(
            id: UUID(),
            user: user,
            tokenHash: "hash",
            expiresAt: Date(),
            revokedAt: nil,
            replacedBy: nil
        )

        #expect(token.user.id == userId)
        #expect(token.user.email == "test@example.com")
    }
}

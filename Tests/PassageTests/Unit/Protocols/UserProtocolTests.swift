import Testing
import Vapor
@testable import Passage

@Suite
struct `User Protocol Tests` {

    // MARK: - Mock User Implementation

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

    // MARK: - Protocol Extension Tests

    @Test
    func `User requiredIdAsString returns string representation of ID`() throws {
        let userId = UUID()
        let user = MockUser(
            id: userId,
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        let idString = try user.requiredIdAsString
        #expect(idString == userId.uuidString)
    }

    @Test
    func `User requiredIdAsString throws when ID is nil`() {
        let user = MockUser(
            id: nil,
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        #expect(throws: PassageError.self) {
            _ = try user.requiredIdAsString
        }
    }

    // MARK: - Email Verification Check Tests

    @Test
    func `User check succeeds for verified email`() throws {
        let user = MockUser(
            id: UUID(),
            email: "test@example.com",
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: true,
            isPhoneVerified: false
        )

        let identifier = Identifier.email("test@example.com")
        try user.check(identifier: identifier)
    }

    @Test
    func `User check throws for unverified email`() {
        let user = MockUser(
            id: UUID(),
            email: "test@example.com",
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        let identifier = Identifier.email("test@example.com")
        #expect(throws: AuthenticationError.emailIsNotVerified) {
            try user.check(identifier: identifier)
        }
    }

    // MARK: - Phone Verification Check Tests

    @Test
    func `User check succeeds for verified phone`() throws {
        let user = MockUser(
            id: UUID(),
            email: nil,
            phone: "+1234567890",
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: true
        )

        let identifier = Identifier.phone("+1234567890")
        try user.check(identifier: identifier)
    }

    @Test
    func `User check throws for unverified phone`() {
        let user = MockUser(
            id: UUID(),
            email: nil,
            phone: "+1234567890",
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        let identifier = Identifier.phone("+1234567890")
        #expect(throws: AuthenticationError.phoneIsNotVerified) {
            try user.check(identifier: identifier)
        }
    }

    // MARK: - equals() Tests

    @Test
    func `User equals returns true when both users have the same ID`() {
        let id = UUID()
        let user1 = MockUser(id: id, email: "a@example.com", phone: nil, username: nil, passwordHash: nil, isAnonymous: false, isEmailVerified: false, isPhoneVerified: false)
        let user2 = MockUser(id: id, email: "b@example.com", phone: nil, username: nil, passwordHash: nil, isAnonymous: false, isEmailVerified: false, isPhoneVerified: false)
        #expect(user1.equals(to: user2))
    }

    @Test
    func `User equals returns false when users have different IDs`() {
        let user1 = MockUser(id: UUID(), email: nil, phone: nil, username: nil, passwordHash: nil, isAnonymous: false, isEmailVerified: false, isPhoneVerified: false)
        let user2 = MockUser(id: UUID(), email: nil, phone: nil, username: nil, passwordHash: nil, isAnonymous: false, isEmailVerified: false, isPhoneVerified: false)
        #expect(!user1.equals(to: user2))
    }

    @Test
    func `User equals returns false when self has nil ID`() {
        let user1 = MockUser(id: nil, email: nil, phone: nil, username: nil, passwordHash: nil, isAnonymous: false, isEmailVerified: false, isPhoneVerified: false)
        let user2 = MockUser(id: UUID(), email: nil, phone: nil, username: nil, passwordHash: nil, isAnonymous: false, isEmailVerified: false, isPhoneVerified: false)
        #expect(!user1.equals(to: user2))
    }

    @Test
    func `User equals returns false when other has nil ID`() {
        let user1 = MockUser(id: UUID(), email: nil, phone: nil, username: nil, passwordHash: nil, isAnonymous: false, isEmailVerified: false, isPhoneVerified: false)
        let user2 = MockUser(id: nil, email: nil, phone: nil, username: nil, passwordHash: nil, isAnonymous: false, isEmailVerified: false, isPhoneVerified: false)
        #expect(!user1.equals(to: user2))
    }

    // MARK: - Username Check Tests

    @Test
    func `User check succeeds for username without verification`() throws {
        let user = MockUser(
            id: UUID(),
            email: nil,
            phone: nil,
            username: "johndoe",
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        let identifier = Identifier.username("johndoe")
        try user.check(identifier: identifier)
    }

    @Test
    func `User check succeeds for federated identifier without requiring verification`() throws {
        let user = MockUser(
            id: UUID(),
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
        let identifier = Identifier.federated(.google, userId: "google-user-123")
        try user.check(identifier: identifier)
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `MockUser conforms to User protocol`() {
        let user: any User = MockUser(
            id: UUID(),
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
        #expect(user is MockUser)
    }

    @Test
    func `User protocol conforms to Sendable`() {
        let user: any Sendable = MockUser(
            id: UUID(),
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
        #expect(user is MockUser)
    }

    // MARK: - User Properties Tests

    @Test
    func `User with all properties set`() {
        let userId = UUID()
        let user = MockUser(
            id: userId,
            email: "test@example.com",
            phone: "+1234567890",
            username: "johndoe",
            passwordHash: "hashed_password",
            isAnonymous: false,
            isEmailVerified: true,
            isPhoneVerified: true
        )

        #expect(user.id == userId)
        #expect(user.email == "test@example.com")
        #expect(user.phone == "+1234567890")
        #expect(user.username == "johndoe")
        #expect(user.passwordHash == "hashed_password")
        #expect(user.isAnonymous == false)
        #expect(user.isEmailVerified == true)
        #expect(user.isPhoneVerified == true)
    }

    @Test
    func `User with minimal properties`() {
        let user = MockUser(
            id: nil,
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: true,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        #expect(user.id == nil)
        #expect(user.email == nil)
        #expect(user.phone == nil)
        #expect(user.username == nil)
        #expect(user.passwordHash == nil)
        #expect(user.isAnonymous == true)
        #expect(user.isEmailVerified == false)
        #expect(user.isPhoneVerified == false)
    }

    // MARK: - ID Type Tests

    @Test
    func `User ID type is CustomStringConvertible`() {
        let userId = UUID()
        let user = MockUser(
            id: userId,
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        let idDescription = user.id?.description
        #expect(idDescription != nil)
        #expect(idDescription == userId.uuidString)
    }

    // MARK: - SessionAuthenticatable Conformance Tests

    @Test
    func `User protocol conforms to SessionAuthenticatable`() {
        let user = MockUser(
            id: UUID(),
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
        #expect(user is any SessionAuthenticatable)
    }

    @Test
    func `User sessionID returns string representation of ID`() {
        let userId = UUID()
        let user = MockUser(
            id: userId,
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        #expect(user.sessionID == userId.uuidString)
    }

    @Test
    func `User conforms to Authenticatable`() {
        let user = MockUser(
            id: UUID(),
            email: nil,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )
        #expect(user is any Authenticatable)
    }
}

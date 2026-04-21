import Testing
import Foundation
@testable import Passage

@Suite
struct `VerificationCode Protocol Tests` {

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

    // MARK: - isExpired Tests

    @Test
    func `VerificationCode isExpired returns true when expired`() {
        let code = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: "test@example.com",
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date().addingTimeInterval(-60), // expired 1 minute ago
            failedAttempts: 0,
            email: "test@example.com"
        )

        #expect(code.isExpired == true)
    }

    @Test
    func `VerificationCode isExpired returns false when not expired`() {
        let code = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: "test@example.com",
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date().addingTimeInterval(900), // expires in 15 minutes
            failedAttempts: 0,
            email: "test@example.com"
        )

        #expect(code.isExpired == false)
    }

    // MARK: - isValid Tests

    @Test
    func `VerificationCode isValid returns true when not expired and under max attempts`() {
        let code = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: "test@example.com",
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date().addingTimeInterval(900),
            failedAttempts: 1,
            email: "test@example.com"
        )

        #expect(code.isValid(maxAttempts: 3) == true)
    }

    @Test
    func `VerificationCode isValid returns false when expired`() {
        let code = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: "test@example.com",
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date().addingTimeInterval(-60),
            failedAttempts: 0,
            email: "test@example.com"
        )

        #expect(code.isValid(maxAttempts: 3) == false)
    }

    @Test
    func `VerificationCode isValid returns false when max attempts reached`() {
        let code = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: "test@example.com",
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date().addingTimeInterval(900),
            failedAttempts: 3,
            email: "test@example.com"
        )

        #expect(code.isValid(maxAttempts: 3) == false)
    }

    @Test
    func `VerificationCode isValid at boundary of max attempts`() {
        let code = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: "test@example.com",
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date().addingTimeInterval(900),
            failedAttempts: 2,
            email: "test@example.com"
        )

        #expect(code.isValid(maxAttempts: 3) == true)
        #expect(code.isValid(maxAttempts: 2) == false)
    }

    // MARK: - EmailVerificationCode Tests

    @Test
    func `EmailVerificationCode stores email correctly`() {
        let email = "test@example.com"
        let code = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: email,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date(),
            failedAttempts: 0,
            email: email
        )

        #expect(code.email == email)
    }

    @Test
    func `EmailVerificationCode conforms to VerificationCode`() {
        let code: any VerificationCode = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: "test@example.com",
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date(),
            failedAttempts: 0,
            email: "test@example.com"
        )

        #expect(code is MockEmailVerificationCode)
    }

    // MARK: - PhoneVerificationCode Tests

    @Test
    func `PhoneVerificationCode stores phone correctly`() {
        let phone = "+1234567890"
        let code = MockPhoneVerificationCode(
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: phone,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date(),
            failedAttempts: 0,
            phone: phone
        )

        #expect(code.phone == phone)
    }

    @Test
    func `PhoneVerificationCode conforms to VerificationCode`() {
        let code: any VerificationCode = MockPhoneVerificationCode(
            user: MockUser(
                id: UUID(),
                email: nil,
                phone: "+1234567890",
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date(),
            failedAttempts: 0,
            phone: "+1234567890"
        )

        #expect(code is MockPhoneVerificationCode)
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `VerificationCode protocol conforms to Sendable`() {
        let code: any Sendable = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: "test@example.com",
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date(),
            failedAttempts: 0,
            email: "test@example.com"
        )
        #expect(code is MockEmailVerificationCode)
    }

    // MARK: - Properties Tests

    @Test
    func `VerificationCode stores codeHash correctly`() {
        let hash = "abc123hash"
        let code = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: "test@example.com",
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: hash,
            expiresAt: Date(),
            failedAttempts: 0,
            email: "test@example.com"
        )

        #expect(code.codeHash == hash)
    }

    @Test
    func `VerificationCode tracks failed attempts`() {
        let code = MockEmailVerificationCode(
            user: MockUser(
                id: UUID(),
                email: "test@example.com",
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            ),
            codeHash: "hash",
            expiresAt: Date(),
            failedAttempts: 2,
            email: "test@example.com"
        )

        #expect(code.failedAttempts == 2)
    }

    @Test
    func `VerificationCode stores user reference`() {
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
        let code = MockEmailVerificationCode(
            user: user,
            codeHash: "hash",
            expiresAt: Date(),
            failedAttempts: 0,
            email: "test@example.com"
        )

        #expect(code.user.id == userId)
        #expect(code.user.email == "test@example.com")
    }
}

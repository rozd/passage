import Testing
import Vapor
@testable import Passage

@Suite
struct `AuthUser Tests` {

    // MARK: - AuthUser Initialization Tests

    @Test
    func `AuthUser initialization with all properties`() {
        let user = AuthUser.User(
            id: "user123",
            email: "test@example.com",
            phone: "+1234567890"
        )

        let authUser = AuthUser(
            accessToken: "access_token_here",
            refreshToken: "refresh_token_here",
            tokenType: "Bearer",
            expiresIn: 3600,
            user: user
        )

        #expect(authUser.accessToken == "access_token_here")
        #expect(authUser.refreshToken == "refresh_token_here")
        #expect(authUser.tokenType == "Bearer")
        #expect(authUser.expiresIn == 3600)
        #expect(authUser.user.id == "user123")
        #expect(authUser.user.email == "test@example.com")
        #expect(authUser.user.phone == "+1234567890")
    }

    @Test
    func `AuthUser with nil email and phone`() {
        let user = AuthUser.User(
            id: "user123",
            email: nil,
            phone: nil
        )

        let authUser = AuthUser(
            accessToken: "access_token",
            refreshToken: "refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            user: user
        )

        #expect(authUser.user.email == nil)
        #expect(authUser.user.phone == nil)
    }

    // MARK: - AuthUser.User Tests

    @Test
    func `AuthUser.User initialization`() {
        let user = AuthUser.User(
            id: "user_id_123",
            email: "john@example.com",
            phone: "+19876543210"
        )

        #expect(user.id == "user_id_123")
        #expect(user.email == "john@example.com")
        #expect(user.phone == "+19876543210")
    }

    @Test
    func `AuthUser.User with only email`() {
        let user = AuthUser.User(
            id: "user123",
            email: "test@example.com",
            phone: nil
        )

        #expect(user.email == "test@example.com")
        #expect(user.phone == nil)
    }

    @Test
    func `AuthUser.User with only phone`() {
        let user = AuthUser.User(
            id: "user123",
            email: nil,
            phone: "+1234567890"
        )

        #expect(user.email == nil)
        #expect(user.phone == "+1234567890")
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `AuthUser conforms to Content`() {
        let user = AuthUser.User(id: "user123", email: "test@example.com", phone: nil)
        let authUser = AuthUser(
            accessToken: "token",
            refreshToken: "refresh",
            tokenType: "Bearer",
            expiresIn: 3600,
            user: user
        )

        let _: any Content = authUser
        #expect(authUser is any Content)
    }

    @Test
    func `AuthUser.User conforms to Content`() {
        let user = AuthUser.User(id: "user123", email: "test@example.com", phone: nil)
        let _: any Content = user
        #expect(user is any Content)
    }

    @Test
    func `AuthUser.User conforms to UserInfo`() {
        let user = AuthUser.User(id: "user123", email: "test@example.com", phone: "+1234567890")
        let _: any UserInfo = user
        #expect(user is any UserInfo)
    }

    // MARK: - Token Type Tests

    @Test
    func `AuthUser with Bearer token type`() {
        let user = AuthUser.User(id: "user123", email: "test@example.com", phone: nil)
        let authUser = AuthUser(
            accessToken: "token",
            refreshToken: "refresh",
            tokenType: "Bearer",
            expiresIn: 3600,
            user: user
        )

        #expect(authUser.tokenType == "Bearer")
    }

    @Test
    func `AuthUser with custom token type`() {
        let user = AuthUser.User(id: "user123", email: "test@example.com", phone: nil)
        let authUser = AuthUser(
            accessToken: "token",
            refreshToken: "refresh",
            tokenType: "Custom",
            expiresIn: 3600,
            user: user
        )

        #expect(authUser.tokenType == "Custom")
    }

    // MARK: - ExpiresIn Tests

    @Test(arguments: [
        300.0,    // 5 minutes
        3600.0,   // 1 hour
        7200.0,   // 2 hours
        86400.0   // 1 day
    ])
    func `AuthUser with different expiresIn values`(expiresIn: TimeInterval) {
        let user = AuthUser.User(id: "user123", email: "test@example.com", phone: nil)
        let authUser = AuthUser(
            accessToken: "token",
            refreshToken: "refresh",
            tokenType: "Bearer",
            expiresIn: expiresIn,
            user: user
        )

        #expect(authUser.expiresIn == expiresIn)
    }

    // MARK: - Token Properties Tests

    @Test
    func `AuthUser stores accessToken correctly`() {
        let user = AuthUser.User(id: "user123", email: "test@example.com", phone: nil)
        let authUser = AuthUser(
            accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
            refreshToken: "refresh_token_value",
            tokenType: "Bearer",
            expiresIn: 3600,
            user: user
        )

        #expect(authUser.accessToken == "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
    }

    @Test
    func `AuthUser stores refreshToken correctly`() {
        let user = AuthUser.User(id: "user123", email: "test@example.com", phone: nil)
        let authUser = AuthUser(
            accessToken: "access_token_value",
            refreshToken: "opaque_refresh_token_12345",
            tokenType: "Bearer",
            expiresIn: 3600,
            user: user
        )

        #expect(authUser.refreshToken == "opaque_refresh_token_12345")
    }

    // MARK: - Nested User Structure Tests

    @Test
    func `AuthUser.User as nested struct`() {
        // Verify that User is properly nested within AuthUser
        let typeName = String(reflecting: AuthUser.User.self)
        #expect(typeName.contains("AuthUser.User"))
    }

    // MARK: - Multiple AuthUser Instances Tests

    @Test
    func `Multiple AuthUser instances are independent`() {
        let user1 = AuthUser.User(id: "user1", email: "user1@example.com", phone: nil)
        let authUser1 = AuthUser(
            accessToken: "token1",
            refreshToken: "refresh1",
            tokenType: "Bearer",
            expiresIn: 3600,
            user: user1
        )

        let user2 = AuthUser.User(id: "user2", email: "user2@example.com", phone: nil)
        let authUser2 = AuthUser(
            accessToken: "token2",
            refreshToken: "refresh2",
            tokenType: "Bearer",
            expiresIn: 7200,
            user: user2
        )

        #expect(authUser1.user.id == "user1")
        #expect(authUser2.user.id == "user2")
        #expect(authUser1.accessToken != authUser2.accessToken)
        #expect(authUser1.expiresIn != authUser2.expiresIn)
    }

    // MARK: - UserInfo Protocol Implementation Tests

    @Test
    func `AuthUser.User email property from UserInfo`() {
        let user: any UserInfo = AuthUser.User(
            id: "user123",
            email: "test@example.com",
            phone: "+1234567890"
        )

        #expect(user.email == "test@example.com")
        #expect(user.phone == "+1234567890")
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `AuthUser conforms to Sendable`() {
        let user = AuthUser.User(id: "123", email: "test@example.com", phone: nil)
        let authUser = AuthUser(
            accessToken: "token",
            refreshToken: "refresh",
            tokenType: "Bearer",
            expiresIn: 3600,
            user: user
        )
        assertSendable(authUser)
    }

    @Test
    func `AuthUser.User conforms to Sendable`() {
        let user = AuthUser.User(id: "123", email: "test@example.com", phone: nil)
        assertSendable(user)
    }
}

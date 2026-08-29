import Foundation
import JWT
@testable import Passage
import Testing

@Suite
struct `Access Token Tests` {

    // MARK: - Initialization Tests

    @Test
    func `Access token initialization with all claims`() {
        let issuedAt = Date()
        let expiresAt = Date(timeIntervalSinceNow: 3600)

        let token = AccessToken(
            userId: "user123",
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            issuer: "https://example.com",
            audience: "api.example.com",
            scope: "read write",
            sessionId: UUID()
        )

        #expect(token.subject.value == "user123")
        #expect(token.issuedAt.value.timeIntervalSince1970 == issuedAt.timeIntervalSince1970)
        #expect(token.expiration.value.timeIntervalSince1970 == expiresAt.timeIntervalSince1970)
        #expect(token.issuer?.value == "https://example.com")
        #expect(token.audience?.value.first == "api.example.com")
        #expect(token.scope == "read write")
    }

    @Test
    func `Access token initialization without optional claims`() {
        let expiresAt = Date(timeIntervalSinceNow: 3600)

        let token = AccessToken(
            userId: "user123",
            expiresAt: expiresAt,
            issuer: nil,
            audience: nil,
            scope: nil,
            sessionId: UUID()
        )

        #expect(token.subject.value == "user123")
        #expect(token.issuer == nil)
        #expect(token.audience == nil)
        #expect(token.scope == nil)
    }

    @Test
    func `Access token default issuedAt`() {
        let beforeCreation = Date()
        let expiresAt = Date(timeIntervalSinceNow: 3600)

        let token = AccessToken(
            userId: "user123",
            expiresAt: expiresAt,
            issuer: nil,
            audience: nil,
            scope: nil,
            sessionId: UUID()
        )

        let afterCreation = Date()

        #expect(token.issuedAt.value >= beforeCreation)
        #expect(token.issuedAt.value <= afterCreation)
    }

    // MARK: - Claims Tests

    @Test(arguments: [
        "user123",
        "user-abc-123",
        "test-user-456"
    ])
    func `Access token subject claim`(userId: String) {
        let token = AccessToken(
            userId: userId,
            expiresAt: Date(timeIntervalSinceNow: 3600),
            issuer: nil,
            audience: nil,
            scope: nil,
            sessionId: UUID()
        )

        #expect(token.subject.value == userId)
    }

    @Test
    func `Access token expiration claim`() {
        let expirationDate = Date(timeIntervalSinceNow: 7200)

        let token = AccessToken(
            userId: "user123",
            expiresAt: expirationDate,
            issuer: nil,
            audience: nil,
            scope: nil,
            sessionId: UUID()
        )

        #expect(token.expiration.value.timeIntervalSince1970 == expirationDate.timeIntervalSince1970)
    }

    @Test
    func `Access token issuedAt claim`() {
        let issuedAtDate = Date(timeIntervalSinceNow: -100)

        let token = AccessToken(
            userId: "user123",
            issuedAt: issuedAtDate,
            expiresAt: Date(timeIntervalSinceNow: 3600),
            issuer: nil,
            audience: nil,
            scope: nil,
            sessionId: UUID()
        )

        #expect(token.issuedAt.value.timeIntervalSince1970 == issuedAtDate.timeIntervalSince1970)
    }

    @Test(arguments: [
        "https://auth.example.com",
        "https://example.com",
        nil
    ])
    func `Access token issuer claim`(issuer: String?) {
        let token = AccessToken(
            userId: "user123",
            expiresAt: Date(timeIntervalSinceNow: 3600),
            issuer: issuer,
            audience: nil,
            scope: nil,
            sessionId: UUID()
        )

        #expect(token.issuer?.value == issuer)
    }

    @Test(arguments: [
        "api.example.com",
        "service.example.com",
        nil
    ])
    func `Access token audience claim`(audience: String?) {
        let token = AccessToken(
            userId: "user123",
            expiresAt: Date(timeIntervalSinceNow: 3600),
            issuer: nil,
            audience: audience,
            scope: nil,
            sessionId: UUID()
        )

        #expect(token.audience?.value.first == audience)
    }

    @Test(arguments: [
        "read write admin",
        "read",
        nil
    ])
    func `Access token scope claim`(scope: String?) {
        let token = AccessToken(
            userId: "user123",
            expiresAt: Date(timeIntervalSinceNow: 3600),
            issuer: nil,
            audience: nil,
            scope: scope,
            sessionId: UUID()
        )

        #expect(token.scope == scope)
    }

    // MARK: - Multiple Tokens Tests

    @Test
    func `Different access tokens have different data`() {
        let token1 = AccessToken(
            userId: "user1",
            expiresAt: Date(timeIntervalSinceNow: 3600),
            issuer: "issuer1",
            audience: "audience1",
            scope: "read",
            sessionId: UUID()
        )

        let token2 = AccessToken(
            userId: "user2",
            expiresAt: Date(timeIntervalSinceNow: 7200),
            issuer: "issuer2",
            audience: "audience2",
            scope: "write",
            sessionId: UUID()
        )

        #expect(token1.subject.value != token2.subject.value)
        #expect(token1.issuer?.value != token2.issuer?.value)
        #expect(token1.audience?.value.first != token2.audience?.value.first)
        #expect(token1.scope != token2.scope)
    }

    // MARK: - Session ID Tests

    @Test
    func `Access token initialization with sessionId`() {
        let sessionId = UUID()
        let expiresAt = Date(timeIntervalSinceNow: 3600)

        let token = AccessToken(
            userId: "user123",
            expiresAt: expiresAt,
            issuer: nil,
            audience: nil,
            scope: nil,
            sessionId: sessionId
        )

        #expect(token.sessionId == sessionId)
    }

}

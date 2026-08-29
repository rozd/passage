@testable import Passage
@testable import PassageOnlyForTest
import Foundation
import Testing

@Suite(.tags(.unit))
struct `InMemoryTokenStore Tests` {

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

    private func makeUser(id: UUID = UUID()) -> MockUser {
        MockUser(
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

    @Test
    func `createRefreshToken persists sessionId`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user = makeUser()
        let sessionId = UUID()
        let expiresAt = Date().addingTimeInterval(3600)

        let token = try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-1",
            expiresAt: expiresAt,
            sessionId: sessionId
        )

        #expect(token.sessionId == sessionId)
    }

    @Test
    func `createRefreshToken rows appear in refreshTokens list`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = try #require(inMemoryStore.tokens as? Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore)
        let user = makeUser()
        let expiresAt = Date().addingTimeInterval(3600)

        try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-1",
            expiresAt: expiresAt,
            sessionId: UUID()
        )
        try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-2",
            expiresAt: expiresAt,
            sessionId: UUID()
        )

        #expect(store.refreshTokens.count == 2)
        let hashes = Set(store.refreshTokens.map(\.tokenHash))
        #expect(hashes.contains("hash-1"))
        #expect(hashes.contains("hash-2"))
    }

    @Test
    func `createRefreshToken with replacing sets replacedBy on old token`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user = makeUser()
        let expiresAt = Date().addingTimeInterval(3600)

        let oldToken = try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-old",
            expiresAt: expiresAt,
            sessionId: UUID()
        )

        _ = try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-new",
            expiresAt: expiresAt,
            sessionId: UUID(),
            replacing: oldToken
        )

        let foundOld = try await store.find(refreshTokenHash: "hash-old")
        #expect(foundOld?.replacedBy != nil)
    }

    @Test
    func `revokeRefreshTokens for user returns session ids of revoked tokens`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user = makeUser()
        let expiresAt = Date().addingTimeInterval(3600)
        let sessionId1 = UUID()
        let sessionId2 = UUID()

        try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-1",
            expiresAt: expiresAt,
            sessionId: sessionId1
        )
        try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-2",
            expiresAt: expiresAt,
            sessionId: sessionId2
        )

        let revoked = try await store.revokeRefreshTokens(for: user)

        #expect(revoked.contains(sessionId1))
        #expect(revoked.contains(sessionId2))
        #expect(revoked.count == 2)
    }

    @Test
    func `revokeRefreshTokens deduplicates same sessionId`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user = makeUser()
        let expiresAt = Date().addingTimeInterval(3600)
        let sessionId = UUID()

        try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-1",
            expiresAt: expiresAt,
            sessionId: sessionId
        )
        try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-2",
            expiresAt: expiresAt,
            sessionId: sessionId
        )

        let revoked = try await store.revokeRefreshTokens(for: user)

        #expect(revoked.count == 1)
        #expect(revoked.first == sessionId)
    }

    @Test
    func `revokeRefreshTokens skips already-revoked tokens`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user = makeUser()
        let expiresAt = Date().addingTimeInterval(3600)
        let sessionId = UUID()

        try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-1",
            expiresAt: expiresAt,
            sessionId: sessionId
        )

        let firstRevoke = try await store.revokeRefreshTokens(for: user)
        #expect(firstRevoke.count == 1)

        let secondRevoke = try await store.revokeRefreshTokens(for: user)
        #expect(secondRevoke == [])
    }

    @Test
    func `revokeRefreshTokens does not touch other users tokens`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user1 = makeUser()
        let user2 = makeUser()
        let expiresAt = Date().addingTimeInterval(3600)
        let sessionId1 = UUID()
        let sessionId2 = UUID()

        try await store.createRefreshToken(
            for: user1,
            tokenHash: "hash-1",
            expiresAt: expiresAt,
            sessionId: sessionId1
        )
        try await store.createRefreshToken(
            for: user2,
            tokenHash: "hash-2",
            expiresAt: expiresAt,
            sessionId: sessionId2
        )

        let revoked = try await store.revokeRefreshTokens(for: user1)
        #expect(revoked.contains(sessionId1))
        #expect(!revoked.contains(sessionId2))

        let user2Token = try await store.find(refreshTokenHash: "hash-2")
        #expect(user2Token?.revokedAt == nil)
    }

    @Test
    func `revokeRefreshTokens for user with nil id returns empty array`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user = MockUser(
            id: nil,
            email: "user@example.com",
            phone: nil,
            username: nil,
            passwordHash: "hash",
            isAnonymous: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        let revoked = try await store.revokeRefreshTokens(for: user)

        #expect(revoked == [])
    }

    @Test
    func `revokeRefreshTokens sessionId only revokes that session`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user = makeUser()
        let expiresAt = Date().addingTimeInterval(3600)
        let sessionId1 = UUID()
        let sessionId2 = UUID()

        try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-1",
            expiresAt: expiresAt,
            sessionId: sessionId1
        )
        try await store.createRefreshToken(
            for: user,
            tokenHash: "hash-2",
            expiresAt: expiresAt,
            sessionId: sessionId2
        )

        try await store.revokeRefreshTokens(sessionId: sessionId1)

        let token1 = try await store.find(refreshTokenHash: "hash-1")
        let token2 = try await store.find(refreshTokenHash: "hash-2")

        #expect(token1?.revokedAt != nil)
        #expect(token2?.revokedAt == nil)
    }

    @Test
    func `revokeRefreshTokens sessionId leaves other users tokens untouched`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user1 = makeUser()
        let user2 = makeUser()
        let expiresAt = Date().addingTimeInterval(3600)
        let sessionId = UUID()

        try await store.createRefreshToken(
            for: user1,
            tokenHash: "hash-1",
            expiresAt: expiresAt,
            sessionId: sessionId
        )
        try await store.createRefreshToken(
            for: user2,
            tokenHash: "hash-2",
            expiresAt: expiresAt,
            sessionId: UUID()
        )

        try await store.revokeRefreshTokens(sessionId: sessionId)

        let user2Token = try await store.find(refreshTokenHash: "hash-2")
        #expect(user2Token?.revokedAt == nil)
    }

    @Test
    func `transaction returns body result`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let result = try await inMemoryStore.transaction { _ in
            return 42
        }

        #expect(result == 42)
    }

    @Test
    func `transaction creates rows when body succeeds`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user = makeUser()
        let expiresAt = Date().addingTimeInterval(3600)

        try await inMemoryStore.transaction { _ in
            try await store.createRefreshToken(
                for: user,
                tokenHash: "hash-tx",
                expiresAt: expiresAt,
                sessionId: UUID()
            )
        }

        let found = try await store.find(refreshTokenHash: "hash-tx")
        #expect(found != nil)
    }

    @Test
    func `transaction rolls back on error`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        let store = inMemoryStore.tokens
        let user = makeUser()
        let expiresAt = Date().addingTimeInterval(3600)

        struct TestError: Error {}

        do {
            try await inMemoryStore.transaction { _ in
                try await store.createRefreshToken(
                    for: user,
                    tokenHash: "hash-rollback",
                    expiresAt: expiresAt,
                    sessionId: UUID()
                )
                throw TestError()
            }
        } catch is TestError {
        }

        let found = try await store.find(refreshTokenHash: "hash-rollback")
        #expect(found == nil)
    }

    @Test
    func `transaction propagates error after rollback`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()

        struct TestError: Error, Equatable {}

        await #expect(throws: TestError.self) {
            try await inMemoryStore.transaction { _ in
                throw TestError()
            }
        }
    }

    @Test
    func `transaction hands the same store to body`() async throws {
        let inMemoryStore = Passage.OnlyForTest.InMemoryStore()
        final class Capture: @unchecked Sendable {
            var storeTokensMatch = false
        }
        let capture = Capture()

        try await inMemoryStore.transaction { store in
            capture.storeTokensMatch = (store.tokens as? Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore) === (inMemoryStore.tokens as? Passage.OnlyForTest.InMemoryStore.InMemoryTokenStore)
        }

        #expect(capture.storeTokensMatch)
    }

}

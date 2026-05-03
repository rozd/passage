import Testing
import Foundation
@testable import Passage
import PassageOnlyForTest

@Suite(.tags(.unit))
struct `InMemoryPasskeyChallengeStore Tests` {

    // MARK: - Mock User

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

    // MARK: - Helpers

    private func makeUser() -> MockUser {
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

    private func makeStore() -> any Passage.PasskeyChallengeStore {
        let inMemory = Passage.OnlyForTest.InMemoryStore()
        guard let store = inMemory.passkeyChallenges else {
            Issue.record("InMemoryStore.passkeyChallenges was nil")
            fatalError()
        }
        return store
    }

    private func makeDTO(
        bytes: Data,
        kind: PasskeyChallengeKind = .registration,
        expiresAt: Date = Date().addingTimeInterval(60)
    ) -> PasskeyChallenge {
        PasskeyChallenge(bytes: bytes, kind: kind, expiresAt: expiresAt)
    }

    // MARK: - Create & Find

    @Test
    func `create then find roundtrips all fields`() async throws {
        let store = makeStore()
        let user = makeUser()
        let bytes = Data("reg-bytes-1".utf8)
        let expiresAt = Date().addingTimeInterval(300)

        _ = try await store.createPasskeyChallenge(
            for: user,
            from: makeDTO(bytes: bytes, kind: .registration, expiresAt: expiresAt)
        )

        let found = try #require(try await store.find(passkeyChallengeMatching: bytes))
        #expect(found.kind == .registration)
        #expect(found.challengeHash == bytes.sha256Hex)
        #expect(found.expiresAt == expiresAt)
        #expect(found.user?.id?.description == user.id?.description)
        #expect(found.consumedAt == nil)
        #expect(found.isValid == true)
    }

    @Test
    func `create without subject stores discoverable challenge`() async throws {
        let store = makeStore()
        let bytes = Data("disc-bytes".utf8)
        let expiresAt = Date().addingTimeInterval(60)

        _ = try await store.createPasskeyChallenge(
            from: makeDTO(bytes: bytes, kind: .authentication, expiresAt: expiresAt)
        )

        let found = try #require(try await store.find(passkeyChallengeMatching: bytes))
        #expect(found.user == nil)
        #expect(found.identifier == nil)
        #expect(found.kind == .authentication)
    }

    @Test
    func `create for identifier stores guest registration challenge`() async throws {
        let store = makeStore()
        let bytes = Data("guest-bytes".utf8)
        let identifier = Identifier.email("guest@example.com")

        _ = try await store.createPasskeyChallenge(
            for: identifier,
            from: makeDTO(bytes: bytes, kind: .registration)
        )

        let found = try #require(try await store.find(passkeyChallengeMatching: bytes))
        #expect(found.user == nil)
        #expect(found.identifier == identifier)
        #expect(found.kind == .registration)
    }

    @Test
    func `find returns nil for unknown bytes`() async throws {
        let store = makeStore()

        let result = try await store.find(passkeyChallengeMatching: Data("never-stored".utf8))

        #expect(result == nil)
    }

    // MARK: - Consume

    @Test
    func `consume marks the challenge as consumed and invalid`() async throws {
        let store = makeStore()
        let user = makeUser()
        let bytes = Data("consume-bytes".utf8)

        let challenge = try await store.createPasskeyChallenge(
            for: user,
            from: makeDTO(bytes: bytes)
        )

        try await store.consume(passkeyChallenge: challenge)

        let found = try #require(try await store.find(passkeyChallengeMatching: bytes))
        #expect(found.consumedAt != nil)
        #expect(found.isConsumed == true)
        #expect(found.isValid == false)
    }

    @Test
    func `consuming one challenge leaves others unaffected`() async throws {
        let store = makeStore()
        let user = makeUser()
        let firstBytes = Data("first".utf8)
        let secondBytes = Data("second".utf8)

        let first = try await store.createPasskeyChallenge(
            for: user,
            from: makeDTO(bytes: firstBytes, kind: .registration)
        )
        _ = try await store.createPasskeyChallenge(
            for: user,
            from: makeDTO(bytes: secondBytes, kind: .authentication)
        )

        try await store.consume(passkeyChallenge: first)

        let secondFound = try #require(try await store.find(passkeyChallengeMatching: secondBytes))
        #expect(secondFound.isConsumed == false)
        #expect(secondFound.isValid == true)
    }

    // MARK: - Cleanup

    @Test
    func `cleanupExpired removes expired challenges but keeps fresh ones`() async throws {
        let store = makeStore()
        let user = makeUser()
        let expired1 = Data("expired-1".utf8)
        let expired2 = Data("expired-2".utf8)
        let fresh = Data("fresh".utf8)

        _ = try await store.createPasskeyChallenge(
            for: user,
            from: makeDTO(bytes: expired1, expiresAt: Date().addingTimeInterval(-10))
        )
        _ = try await store.createPasskeyChallenge(
            for: user,
            from: makeDTO(bytes: expired2, expiresAt: Date().addingTimeInterval(-1))
        )
        _ = try await store.createPasskeyChallenge(
            for: user,
            from: makeDTO(bytes: fresh, kind: .authentication, expiresAt: Date().addingTimeInterval(60))
        )

        try await store.cleanupExpiredPasskeyChallenges(before: Date())

        #expect(try await store.find(passkeyChallengeMatching: expired1) == nil)
        #expect(try await store.find(passkeyChallengeMatching: expired2) == nil)
        #expect(try await store.find(passkeyChallengeMatching: fresh) != nil)
    }

    @Test
    func `cleanupExpired on empty store is a no-op`() async throws {
        let store = makeStore()

        try await store.cleanupExpiredPasskeyChallenges(before: Date())

        #expect(Bool(true))
    }

    // MARK: - Helper property behaviour through the stored type

    @Test
    func `isExpired reflects past expiresAt`() async throws {
        let store = makeStore()
        let user = makeUser()
        let bytes = Data("past".utf8)

        _ = try await store.createPasskeyChallenge(
            for: user,
            from: makeDTO(bytes: bytes, expiresAt: Date().addingTimeInterval(-5))
        )

        let found = try #require(try await store.find(passkeyChallengeMatching: bytes))
        #expect(found.isExpired == true)
        #expect(found.isValid == false)
    }
}

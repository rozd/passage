import Testing
import Foundation
@testable import Passage

@Suite("PasskeyChallengeStore Protocol Tests", .tags(.unit))
struct PasskeyChallengeStoreProtocolTests {

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

    struct MockStoredPasskeyChallenge: StoredPasskeyChallenge {
        typealias Id = UUID
        typealias AssociatedUser = MockUser

        var id: UUID?
        var user: MockUser?
        var kind: PasskeyChallengeKind
        var challengeHash: String
        var expiresAt: Date
        var consumedAt: Date?
        var createdAt: Date?
    }

    struct MockPasskeyChallengeStore: Passage.PasskeyChallengeStore {

        @discardableResult
        func createPasskeyChallenge(
            for user: (any User)?,
            from challenge: PasskeyChallenge
        ) async throws -> any StoredPasskeyChallenge {
            MockStoredPasskeyChallenge(
                id: UUID(),
                user: user as? MockUser,
                kind: challenge.kind,
                challengeHash: challenge.bytes.sha256Hex,
                expiresAt: challenge.expiresAt,
                consumedAt: nil,
                createdAt: Date()
            )
        }

        func find(passkeyChallengeMatching bytes: Data) async throws -> (any StoredPasskeyChallenge)? {
            nil
        }

        func consume(passkeyChallenge: any StoredPasskeyChallenge) async throws {
            // method signature test
        }

        func cleanupExpiredPasskeyChallenges(before date: Date) async throws {
            // method signature test
        }
    }

    // MARK: - Helpers

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

    private func makeChallengeDTO(
        bytes: Data = Data([0x01, 0x02, 0x03]),
        kind: PasskeyChallengeKind = .registration,
        expiresAt: Date = Date().addingTimeInterval(300)
    ) -> PasskeyChallenge {
        PasskeyChallenge(bytes: bytes, kind: kind, expiresAt: expiresAt)
    }

    private func makeStored(
        expiresAt: Date = Date().addingTimeInterval(60),
        consumedAt: Date? = nil
    ) -> MockStoredPasskeyChallenge {
        MockStoredPasskeyChallenge(
            id: UUID(),
            user: createMockUser(),
            kind: .registration,
            challengeHash: "hash",
            expiresAt: expiresAt,
            consumedAt: consumedAt,
            createdAt: Date()
        )
    }

    // MARK: - Protocol Conformance Tests

    @Test("PasskeyChallengeStore protocol can be implemented")
    func protocolCanBeImplemented() {
        let store: any Passage.PasskeyChallengeStore = MockPasskeyChallengeStore()
        #expect(store is MockPasskeyChallengeStore)
    }

    @Test("PasskeyChallengeStore is Sendable")
    func protocolIsSendable() {
        let store: any Sendable = MockPasskeyChallengeStore()
        #expect(store is MockPasskeyChallengeStore)
    }

    // MARK: - Method Signature Tests

    @Test("createPasskeyChallenge accepts PasskeyChallenge DTO and returns a stored record")
    func createReturnsChallenge() async throws {
        let store = MockPasskeyChallengeStore()
        let user = createMockUser()
        let bytes = Data([0xAA, 0xBB, 0xCC])
        let expiresAt = Date().addingTimeInterval(300)
        let dto = PasskeyChallenge(bytes: bytes, kind: .registration, expiresAt: expiresAt)

        let challenge = try await store.createPasskeyChallenge(for: user, from: dto)

        #expect(challenge is MockStoredPasskeyChallenge)
        #expect(challenge.challengeHash == bytes.sha256Hex)
        #expect(challenge.kind == .registration)
        #expect(challenge.expiresAt == expiresAt)
    }

    @Test("createPasskeyChallenge accepts nil user for discoverable flow")
    func createAllowsNilUser() async throws {
        let store = MockPasskeyChallengeStore()
        let dto = makeChallengeDTO(kind: .authentication, expiresAt: Date().addingTimeInterval(60))

        let challenge = try await store.createPasskeyChallenge(for: nil, from: dto)

        #expect(challenge.user == nil)
        #expect(challenge.kind == .authentication)
    }

    @Test("find returns nil for unknown bytes")
    func findReturnsNilForUnknown() async throws {
        let store = MockPasskeyChallengeStore()

        let result = try await store.find(passkeyChallengeMatching: Data([0xDE, 0xAD]))

        #expect(result == nil)
    }

    // MARK: - Discardable Result Test

    @Test("createPasskeyChallenge is discardable")
    func createIsDiscardable() async throws {
        let store = MockPasskeyChallengeStore()

        try await store.createPasskeyChallenge(for: nil, from: makeChallengeDTO())

        #expect(Bool(true))
    }

    // MARK: - Helper Extension Tests

    @Test("fresh unconsumed challenge is valid")
    func freshChallengeIsValid() {
        let challenge = makeStored()
        #expect(challenge.isExpired == false)
        #expect(challenge.isConsumed == false)
        #expect(challenge.isValid == true)
    }

    @Test("expired challenge is not valid")
    func expiredChallengeIsInvalid() {
        let challenge = makeStored(expiresAt: Date().addingTimeInterval(-1))
        #expect(challenge.isExpired == true)
        #expect(challenge.isValid == false)
    }

    @Test("consumed challenge is not valid")
    func consumedChallengeIsInvalid() {
        let challenge = makeStored(consumedAt: Date())
        #expect(challenge.isConsumed == true)
        #expect(challenge.isValid == false)
    }

    // MARK: - Store Protocol Integration

    @Test("Store protocol exposes passkeyChallenges as optional property")
    func storeExposesPasskeyChallenges() {
        struct TestStore: Passage.Store {
            var users: any Passage.UserStore { fatalError() }
            var tokens: any Passage.TokenStore { fatalError() }
            var verificationCodes: any Passage.VerificationCodeStore { fatalError() }
            var restorationCodes: any Passage.RestorationCodeStore { fatalError() }
            var magicLinkTokens: any Passage.MagicLinkTokenStore { fatalError() }
            var exchangeTokens: any Passage.ExchangeTokenStore { fatalError() }
            var passkeyChallenges: (any Passage.PasskeyChallengeStore)? { MockPasskeyChallengeStore() }
        }

        let store: any Passage.Store = TestStore()
        #expect(store.passkeyChallenges is MockPasskeyChallengeStore)
    }

    @Test("Store passkeyChallenges defaults to nil when not provided")
    func storePasskeyChallengesDefaultsToNil() {
        struct LegacyStore: Passage.Store {
            var users: any Passage.UserStore { fatalError() }
            var tokens: any Passage.TokenStore { fatalError() }
            var verificationCodes: any Passage.VerificationCodeStore { fatalError() }
            var restorationCodes: any Passage.RestorationCodeStore { fatalError() }
            var magicLinkTokens: any Passage.MagicLinkTokenStore { fatalError() }
            var exchangeTokens: any Passage.ExchangeTokenStore { fatalError() }
            // default-nil extension applies to passkeyChallenges
        }

        let store: any Passage.Store = LegacyStore()
        #expect(store.passkeyChallenges == nil)
    }
}

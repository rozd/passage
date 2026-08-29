import Testing
import Foundation
@testable import Passage

@Suite(.tags(.unit))
struct `PasskeyCredentialStore Protocol Tests` {

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

    struct MockStoredPasskeyCredential: StoredPasskeyCredential {
        typealias Id = UUID
        typealias AssociatedUser = MockUser

        var id: UUID?
        var user: MockUser
        var credentialID: String
        var publicKey: Data
        var signCount: UInt32
        var uvInitialized: Bool
        var transports: [AuthenticatorTransport]
        var backupEligible: Bool
        var isBackedUp: Bool
        var aaguid: String?
        var attestationFormat: String?
        var createdAt: Date?
        var updatedAt: Date?
    }

    struct MockPasskeyCredentialStore: Passage.PasskeyCredentialStore {

        @discardableResult
        func createPasskeyCredential(
            for user: any User,
            from credential: PasskeyCredential
        ) async throws -> any StoredPasskeyCredential {
            MockStoredPasskeyCredential(
                id: UUID(),
                user: user as! MockUser,
                credentialID: credential.credentialID,
                publicKey: credential.publicKey,
                signCount: credential.signCount,
                uvInitialized: credential.uvInitialized,
                transports: credential.transports,
                backupEligible: credential.backupEligible,
                isBackedUp: credential.isBackedUp,
                aaguid: credential.aaguid,
                attestationFormat: credential.attestationFormat,
                createdAt: Date(),
                updatedAt: Date()
            )
        }

        func find(byCredentialID credentialID: String) async throws -> (any StoredPasskeyCredential)? {
            nil
        }

        func listPasskeyCredentials(forUser user: any User) async throws -> [any StoredPasskeyCredential] {
            []
        }

        func updatePasskeyCredentialAfterAuthentication(
            forCredentialID credentialID: String,
            newSignCount: UInt32,
            isBackedUp: Bool
        ) async throws {
            // method signature test
        }

        func deletePasskeyCredential(byCredentialID credentialID: String) async throws {
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

    private func createSampleCredential(id: String = "cred-1") -> PasskeyCredential {
        PasskeyCredential(
            credentialID: id,
            publicKey: Data([0x01, 0x02, 0x03]),
            signCount: 0,
            uvInitialized: true,
            transports: [.internal, .hybrid],
            backupEligible: true,
            isBackedUp: false,
            aaguid: "aaguid-xyz",
            attestationFormat: "none"
        )
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `PasskeyCredentialStore protocol can be implemented`() {
        let store: any Passage.PasskeyCredentialStore = MockPasskeyCredentialStore()
        #expect(store is MockPasskeyCredentialStore)
    }

    @Test
    func `PasskeyCredentialStore is Sendable`() {
        let store: any Sendable = MockPasskeyCredentialStore()
        #expect(store is MockPasskeyCredentialStore)
    }

    // MARK: - Method Signature Tests

    @Test
    func `createPasskeyCredential returns StoredPasskeyCredential`() async throws {
        let store = MockPasskeyCredentialStore()
        let user = createMockUser()
        let credential = createSampleCredential()

        let stored = try await store.createPasskeyCredential(for: user, from: credential)

        #expect(stored is MockStoredPasskeyCredential)
        #expect(stored.credentialID == credential.credentialID)
    }

    @Test
    func `createPasskeyCredential propagates credential fields`() async throws {
        let store = MockPasskeyCredentialStore()
        let user = createMockUser()
        let credential = createSampleCredential()

        let stored = try await store.createPasskeyCredential(for: user, from: credential)

        #expect(stored.publicKey == credential.publicKey)
        #expect(stored.signCount == credential.signCount)
        #expect(stored.uvInitialized == credential.uvInitialized)
        #expect(stored.transports == credential.transports)
        #expect(stored.backupEligible == credential.backupEligible)
        #expect(stored.isBackedUp == credential.isBackedUp)
        #expect(stored.aaguid == credential.aaguid)
        #expect(stored.attestationFormat == credential.attestationFormat)
    }

    @Test
    func `createPasskeyCredential binds to user`() async throws {
        let store = MockPasskeyCredentialStore()
        let user = createMockUser()
        let credential = createSampleCredential()

        let stored = try await store.createPasskeyCredential(for: user, from: credential)

        #expect(stored.user.id?.description == user.id?.description)
    }

    @Test
    func `find returns nil for unknown credentialID`() async throws {
        let store = MockPasskeyCredentialStore()

        let result = try await store.find(byCredentialID: "does-not-exist")

        #expect(result == nil)
    }

    @Test
    func `listPasskeyCredentials returns empty for user with none`() async throws {
        let store = MockPasskeyCredentialStore()
        let user = createMockUser()

        let result = try await store.listPasskeyCredentials(forUser: user)

        #expect(result.isEmpty)
    }

    // MARK: - Discardable Result Test

    @Test
    func `createPasskeyCredential is discardable`() async throws {
        let store = MockPasskeyCredentialStore()
        let user = createMockUser()
        let credential = createSampleCredential()

        try await store.createPasskeyCredential(for: user, from: credential)

        #expect(Bool(true))
    }

    // MARK: - Store Protocol Integration

    @Test
    func `Store protocol exposes passkeyCredentials as optional property`() {
        struct TestStore: Passage.Store {
            var users: any Passage.UserStore { fatalError() }
            var tokens: any Passage.TokenStore { fatalError() }
            var verificationCodes: any Passage.VerificationCodeStore { fatalError() }
            var restorationCodes: any Passage.RestorationCodeStore { fatalError() }
            var magicLinkTokens: any Passage.MagicLinkTokenStore { fatalError() }
            var exchangeTokens: any Passage.ExchangeTokenStore { fatalError() }
            func transaction<T: Sendable>(_ body: @Sendable (any Passage.Store) async throws -> T) async throws -> T {
                try await body(self)
            }
            var passkeyCredentials: (any Passage.PasskeyCredentialStore)? { MockPasskeyCredentialStore() }
        }

        let store: any Passage.Store = TestStore()
        #expect(store.passkeyCredentials is MockPasskeyCredentialStore)
    }

    @Test
    func `Store passkeyCredentials defaults to nil when not provided`() {
        struct LegacyStore: Passage.Store {
            var users: any Passage.UserStore { fatalError() }
            var tokens: any Passage.TokenStore { fatalError() }
            var verificationCodes: any Passage.VerificationCodeStore { fatalError() }
            var restorationCodes: any Passage.RestorationCodeStore { fatalError() }
            var magicLinkTokens: any Passage.MagicLinkTokenStore { fatalError() }
            var exchangeTokens: any Passage.ExchangeTokenStore { fatalError() }
            func transaction<T: Sendable>(_ body: @Sendable (any Passage.Store) async throws -> T) async throws -> T {
                try await body(self)
            }
            // Intentionally no passkeyCredentials override — default-nil extension applies.
        }

        let store: any Passage.Store = LegacyStore()
        #expect(store.passkeyCredentials == nil)
    }
}

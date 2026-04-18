import Testing
import Foundation
@testable import Passage
import PassageOnlyForTest

@Suite("InMemoryPasskeyCredentialStore Tests", .tags(.unit))
struct InMemoryPasskeyCredentialStoreTests {

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

    private func makeUser(email: String = "alice@example.com") -> MockUser {
        MockUser(
            id: UUID(),
            email: email,
            phone: nil,
            username: nil,
            passwordHash: nil,
            isAnonymous: false,
            isEmailVerified: true,
            isPhoneVerified: false
        )
    }

    private func makeCredential(id: String = "cred-\(UUID().uuidString)") -> PasskeyCredential {
        PasskeyCredential(
            credentialID: id,
            publicKey: Data([0x04, 0xDE, 0xAD, 0xBE, 0xEF]),
            signCount: 0,
            uvInitialized: true,
            transports: [.internal, .hybrid],
            backupEligible: true,
            isBackedUp: false,
            aaguid: "00000000-0000-0000-0000-000000000000",
            attestationFormat: "none"
        )
    }

    private func makeStore() -> any Passage.PasskeyCredentialStore {
        let inMemory = Passage.OnlyForTest.InMemoryStore()
        guard let store = inMemory.passkeyCredentials else {
            Issue.record("InMemoryStore.passkeyCredentials was nil")
            fatalError()
        }
        return store
    }

    // MARK: - Create & Find

    @Test("create then find returns the same credential")
    func createThenFind() async throws {
        let store = makeStore()
        let user = makeUser()
        let credential = makeCredential(id: "cred-1")

        let stored = try await store.createPasskeyCredential(for: user, from: credential)
        let found = try await store.find(byCredentialID: "cred-1")

        #expect(found != nil)
        #expect(found?.credentialID == stored.credentialID)
    }

    @Test("create preserves all W3C credential-record fields")
    func createPreservesAllFields() async throws {
        let store = makeStore()
        let user = makeUser()
        let credential = makeCredential(id: "cred-roundtrip")

        _ = try await store.createPasskeyCredential(for: user, from: credential)
        let found = try #require(try await store.find(byCredentialID: "cred-roundtrip"))

        #expect(found.credentialID == credential.credentialID)
        #expect(found.publicKey == credential.publicKey)
        #expect(found.signCount == credential.signCount)
        #expect(found.uvInitialized == credential.uvInitialized)
        #expect(found.transports == credential.transports)
        #expect(found.backupEligible == credential.backupEligible)
        #expect(found.isBackedUp == credential.isBackedUp)
        #expect(found.aaguid == credential.aaguid)
        #expect(found.attestationFormat == credential.attestationFormat)
    }

    @Test("create stamps createdAt and updatedAt")
    func createStampsTimestamps() async throws {
        let store = makeStore()
        let user = makeUser()
        let before = Date()

        let stored = try await store.createPasskeyCredential(for: user, from: makeCredential(id: "cred-ts"))

        #expect(stored.createdAt != nil)
        #expect(stored.updatedAt != nil)
        #expect((stored.createdAt ?? .distantPast) >= before)
    }

    @Test("find returns nil for unknown credentialID")
    func findReturnsNilForUnknown() async throws {
        let store = makeStore()

        let result = try await store.find(byCredentialID: "never-stored")

        #expect(result == nil)
    }

    // MARK: - List

    @Test("listPasskeyCredentials returns empty for user with none")
    func listEmptyForNewUser() async throws {
        let store = makeStore()
        let user = makeUser()

        let result = try await store.listPasskeyCredentials(forUser: user)

        #expect(result.isEmpty)
    }

    @Test("listPasskeyCredentials returns only that user's credentials")
    func listIsolatesPerUser() async throws {
        let store = makeStore()
        let alice = makeUser(email: "alice@example.com")
        let bob = makeUser(email: "bob@example.com")

        _ = try await store.createPasskeyCredential(for: alice, from: makeCredential(id: "alice-1"))
        _ = try await store.createPasskeyCredential(for: alice, from: makeCredential(id: "alice-2"))
        _ = try await store.createPasskeyCredential(for: bob, from: makeCredential(id: "bob-1"))

        let aliceList = try await store.listPasskeyCredentials(forUser: alice)
        let bobList = try await store.listPasskeyCredentials(forUser: bob)

        #expect(aliceList.count == 2)
        #expect(bobList.count == 1)
        #expect(Set(aliceList.map(\.credentialID)) == ["alice-1", "alice-2"])
        #expect(bobList.first?.credentialID == "bob-1")
    }

    // MARK: - Update

    @Test("update changes signCount and isBackedUp")
    func updateMutatesAuthFields() async throws {
        let store = makeStore()
        let user = makeUser()
        _ = try await store.createPasskeyCredential(for: user, from: makeCredential(id: "cred-upd"))

        try await store.updatePasskeyCredentialAfterAuthentication(
            forCredentialID: "cred-upd",
            newSignCount: 42,
            isBackedUp: true
        )

        let found = try #require(try await store.find(byCredentialID: "cred-upd"))
        #expect(found.signCount == 42)
        #expect(found.isBackedUp == true)
    }

    @Test("update preserves immutable fields")
    func updatePreservesImmutables() async throws {
        let store = makeStore()
        let user = makeUser()
        let credential = makeCredential(id: "cred-immut")
        let originalStored = try await store.createPasskeyCredential(for: user, from: credential)
        let originalCreatedAt = originalStored.createdAt

        try await store.updatePasskeyCredentialAfterAuthentication(
            forCredentialID: "cred-immut",
            newSignCount: 7,
            isBackedUp: true
        )

        let found = try #require(try await store.find(byCredentialID: "cred-immut"))
        #expect(found.publicKey == credential.publicKey)
        #expect(found.credentialID == credential.credentialID)
        #expect(found.uvInitialized == credential.uvInitialized)
        #expect(found.aaguid == credential.aaguid)
        #expect(found.createdAt == originalCreatedAt)
    }

    @Test("update bumps updatedAt")
    func updateBumpsUpdatedAt() async throws {
        let store = makeStore()
        let user = makeUser()
        let stored = try await store.createPasskeyCredential(for: user, from: makeCredential(id: "cred-updbump"))
        let originalUpdatedAt = stored.updatedAt

        // Small delay so wall-clock differs
        try await Task.sleep(nanoseconds: 5_000_000)

        try await store.updatePasskeyCredentialAfterAuthentication(
            forCredentialID: "cred-updbump",
            newSignCount: 1,
            isBackedUp: false
        )

        let found = try #require(try await store.find(byCredentialID: "cred-updbump"))
        #expect((found.updatedAt ?? .distantPast) > (originalUpdatedAt ?? .distantPast))
    }

    // MARK: - Delete

    @Test("delete removes the credential")
    func deleteRemovesCredential() async throws {
        let store = makeStore()
        let user = makeUser()
        _ = try await store.createPasskeyCredential(for: user, from: makeCredential(id: "cred-del"))

        try await store.deletePasskeyCredential(byCredentialID: "cred-del")

        let result = try await store.find(byCredentialID: "cred-del")
        #expect(result == nil)
    }

    @Test("delete for unknown credentialID is a no-op")
    func deleteUnknownIsNoop() async throws {
        let store = makeStore()

        // Should not throw
        try await store.deletePasskeyCredential(byCredentialID: "never-existed")

        #expect(Bool(true))
    }
}

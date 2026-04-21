import Testing
import Foundation
@testable import Passage

@Suite(.tags(.unit, .federatedLogin))
struct `Linking Result Tests` {

    // MARK: - Mock User

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
            guard let id = id else { fatalError() }
            return id.uuidString
        }
    }

    // MARK: - Case Tests

    @Test
    func `Linking.Result.complete stores user`() {
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

        let result = Passage.Linking.Result.complete(user: user)

        if case .complete(let storedUser) = result {
            #expect(storedUser.email == "test@example.com")
        } else {
            Issue.record("Expected .complete case")
        }
    }

    @Test
    func `Linking.Result.conflict stores candidate IDs`() {
        let candidates = ["user-1", "user-2", "user-3"]
        let result = Passage.Linking.Result.conflict(candidates: candidates)

        if case .conflict(let storedCandidates) = result {
            #expect(storedCandidates == candidates)
            #expect(storedCandidates.count == 3)
        } else {
            Issue.record("Expected .conflict case")
        }
    }

    @Test
    func `Linking.Result.conflict with empty candidates`() {
        let result = Passage.Linking.Result.conflict(candidates: [])

        if case .conflict(let candidates) = result {
            #expect(candidates.isEmpty)
        } else {
            Issue.record("Expected .conflict case")
        }
    }

    @Test
    func `Linking.Result.initiated has no associated values`() {
        let result = Passage.Linking.Result.initiated

        if case .initiated = result {
            // Test passes - this is the expected case
            #expect(Bool(true))
        } else {
            Issue.record("Expected .initiated case")
        }
    }

    @Test
    func `Linking.Result.skipped has no associated values`() {
        let result = Passage.Linking.Result.skipped

        if case .skipped = result {
            // Test passes - this is the expected case
            #expect(Bool(true))
        } else {
            Issue.record("Expected .skipped case")
        }
    }

    // MARK: - Case Distinction Tests

    @Test
    func `All Linking.Result cases are distinct`() {
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

        let complete = Passage.Linking.Result.complete(user: user)
        let conflict = Passage.Linking.Result.conflict(candidates: ["1"])
        let initiated = Passage.Linking.Result.initiated
        let skipped = Passage.Linking.Result.skipped

        // Verify each case is distinct using pattern matching
        if case .complete = complete {
            #expect(Bool(true))
        } else {
            Issue.record("complete should match .complete")
        }

        if case .conflict = conflict {
            #expect(Bool(true))
        } else {
            Issue.record("conflict should match .conflict")
        }

        if case .initiated = initiated {
            #expect(Bool(true))
        } else {
            Issue.record("initiated should match .initiated")
        }

        if case .skipped = skipped {
            #expect(Bool(true))
        } else {
            Issue.record("skipped should match .skipped")
        }
    }

    // MARK: - Sendable Conformance

    @Test
    func `Linking.Result conforms to Sendable`() {
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

        let results: [any Sendable] = [
            Passage.Linking.Result.complete(user: user),
            Passage.Linking.Result.conflict(candidates: ["1"]),
            Passage.Linking.Result.initiated,
            Passage.Linking.Result.skipped
        ]

        #expect(results.count == 4)
    }

    // MARK: - Use Case Tests

    @Test
    func `Linking.Result.complete represents successful automatic linking`() {
        // When automatic linking finds exactly one matching user
        let linkedUser = MockUser(
            id: UUID(),
            email: "existing@example.com",
            phone: nil,
            username: nil,
            passwordHash: "hashed",
            isAnonymous: false,
            isEmailVerified: true,
            isPhoneVerified: false
        )

        let result = Passage.Linking.Result.complete(user: linkedUser)

        if case .complete(let user) = result {
            #expect(user.isEmailVerified)
            #expect(user.email == "existing@example.com")
        } else {
            Issue.record("Expected .complete case")
        }
    }

    @Test
    func `Linking.Result.conflict represents multiple matching users`() {
        // When multiple users match the federated identity's verified emails
        let candidateIds = ["uuid-1", "uuid-2"]
        let result = Passage.Linking.Result.conflict(candidates: candidateIds)

        if case .conflict(let candidates) = result {
            #expect(candidates.count == 2)
            #expect(candidates.contains("uuid-1"))
            #expect(candidates.contains("uuid-2"))
        } else {
            Issue.record("Expected .conflict case")
        }
    }

    @Test
    func `Linking.Result.initiated represents manual linking flow started`() {
        // When manual linking is configured and candidates exist
        let result = Passage.Linking.Result.initiated

        if case .initiated = result {
            // User should be redirected to account selection UI
            #expect(Bool(true))
        } else {
            Issue.record("Expected .initiated case")
        }
    }

    @Test
    func `Linking.Result.skipped represents no matching users`() {
        // When no existing users match the federated identity
        let result = Passage.Linking.Result.skipped

        if case .skipped = result {
            // A new user should be created
            #expect(Bool(true))
        } else {
            Issue.record("Expected .skipped case")
        }
    }
}

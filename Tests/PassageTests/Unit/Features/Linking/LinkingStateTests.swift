import Testing
import Foundation
@testable import Passage

@Suite(.tags(.unit, .federatedLogin))
struct `Linking State Tests` {

    // MARK: - Type Aliases for Convenience

    typealias LinkingState = Passage.Linking.ManualLinking.LinkingState
    typealias Candidate = LinkingState.Candidate

    // MARK: - Candidate Tests

    @Test
    func `Candidate stores all properties correctly`() {
        let candidate = Candidate(
            userId: "user-123",
            email: "test@example.com",
            phone: "+1234567890",
            hasPassword: true,
            isEmailVerified: true,
            isPhoneVerified: false
        )

        #expect(candidate.userId == "user-123")
        #expect(candidate.email == "test@example.com")
        #expect(candidate.phone == "+1234567890")
        #expect(candidate.hasPassword == true)
        #expect(candidate.isEmailVerified == true)
        #expect(candidate.isPhoneVerified == false)
    }

    @Test
    func `Candidate with nil email and phone`() {
        let candidate = Candidate(
            userId: "user-456",
            email: nil,
            phone: nil,
            hasPassword: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        #expect(candidate.email == nil)
        #expect(candidate.phone == nil)
    }

    @Test
    func `Candidate is Codable`() throws {
        let candidate = Candidate(
            userId: "user-789",
            email: "codable@example.com",
            phone: nil,
            hasPassword: true,
            isEmailVerified: true,
            isPhoneVerified: false
        )

        let encoded = try JSONEncoder().encode(candidate)
        let decoded = try JSONDecoder().decode(Candidate.self, from: encoded)

        #expect(decoded.userId == candidate.userId)
        #expect(decoded.email == candidate.email)
        #expect(decoded.hasPassword == candidate.hasPassword)
    }

    @Test
    func `Candidate is Sendable`() {
        let candidate: any Sendable = Candidate(
            userId: "user-1",
            email: nil,
            phone: nil,
            hasPassword: false,
            isEmailVerified: false,
            isPhoneVerified: false
        )

        #expect(candidate is Candidate)
    }

    // MARK: - LinkingState Initialization Tests

    @Test
    func `LinkingState initializes with correct properties`() {
        let identifier = Identifier.federated(.google, userId: "123")
        let candidates = [
            Candidate(userId: "u1", email: "a@example.com", phone: nil, hasPassword: true, isEmailVerified: true, isPhoneVerified: false)
        ]

        let state = LinkingState(
            federatedIdentifier: identifier,
            candidates: candidates,
            provider: .google,
            ttl: 600
        )

        #expect(state.federatedIdentifier.value == identifier.value)
        #expect(state.candidates.count == 1)
        #expect(state.provider.description == "google")
        #expect(state.selectedUserId == nil)
        #expect(state.sentEmailCode == nil)
        #expect(state.sentPhoneCode == nil)
    }

    @Test
    func `LinkingState sets createdAt to current date`() {
        let before = Date()

        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: 600
        )

        let after = Date()

        #expect(state.createdAt >= before)
        #expect(state.createdAt <= after)
    }

    @Test
    func `LinkingState sets expiresAt based on TTL`() {
        let ttl: TimeInterval = 300 // 5 minutes
        let before = Date().addingTimeInterval(ttl)

        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: ttl
        )

        let after = Date().addingTimeInterval(ttl)

        #expect(state.expiresAt >= before)
        #expect(state.expiresAt <= after)
    }

    // MARK: - isExpired Tests

    @Test
    func `LinkingState isExpired returns false when not expired`() {
        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: 600 // 10 minutes in the future
        )

        #expect(state.isExpired == false)
    }

    @Test
    func `LinkingState isExpired returns true when expired`() {
        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: -60 // 1 minute in the past
        )

        #expect(state.isExpired == true)
    }

    // MARK: - Immutable Update Methods Tests

    @Test
    func `withSelectedUser returns new state with selected user`() {
        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: 600
        )

        let updatedState = state.withSelectedUser("user-selected")

        // Original state unchanged
        #expect(state.selectedUserId == nil)

        // New state has selected user
        #expect(updatedState.selectedUserId == "user-selected")

        // Other properties preserved
        #expect(updatedState.federatedIdentifier.value == state.federatedIdentifier.value)
        #expect(updatedState.provider == state.provider)
    }

    @Test
    func `withEmailCode returns new state with email code`() {
        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: 600
        )

        let updatedState = state.withEmailCode("ABC123")

        // Original state unchanged
        #expect(state.sentEmailCode == nil)

        // New state has email code
        #expect(updatedState.sentEmailCode == "ABC123")

        // Other properties preserved
        #expect(updatedState.federatedIdentifier.value == state.federatedIdentifier.value)
    }

    @Test
    func `withPhoneCode returns new state with phone code`() {
        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: 600
        )

        let updatedState = state.withPhoneCode("XYZ789")

        // Original state unchanged
        #expect(state.sentPhoneCode == nil)

        // New state has phone code
        #expect(updatedState.sentPhoneCode == "XYZ789")
    }

    @Test
    func `Chaining update methods`() {
        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: 600
        )

        let finalState = state
            .withSelectedUser("user-1")
            .withEmailCode("CODE123")

        #expect(finalState.selectedUserId == "user-1")
        #expect(finalState.sentEmailCode == "CODE123")
        #expect(finalState.sentPhoneCode == nil)
    }

    // MARK: - Codable Tests

    @Test
    func `LinkingState is Codable`() throws {
        let candidates = [
            Candidate(userId: "u1", email: "a@example.com", phone: nil, hasPassword: true, isEmailVerified: true, isPhoneVerified: false),
            Candidate(userId: "u2", email: nil, phone: "+123", hasPassword: false, isEmailVerified: false, isPhoneVerified: true)
        ]

        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "abc"),
            candidates: candidates,
            provider: .google,
            ttl: 600
        )
            .withSelectedUser("u1")
            .withEmailCode("TESTCODE")

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(LinkingState.self, from: encoded)

        #expect(decoded.federatedIdentifier.value == state.federatedIdentifier.value)
        #expect(decoded.candidates.count == 2)
        #expect(decoded.provider.description == "google")
        #expect(decoded.selectedUserId == "u1")
        #expect(decoded.sentEmailCode == "TESTCODE")
        #expect(decoded.sentPhoneCode == nil)
    }

    @Test
    func `LinkingState preserves dates through encoding`() throws {
        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: 600
        )

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(LinkingState.self, from: encoded)

        // Dates should be within 1 second (accounting for encoding precision)
        #expect(abs(decoded.createdAt.timeIntervalSince(state.createdAt)) < 1)
        #expect(abs(decoded.expiresAt.timeIntervalSince(state.expiresAt)) < 1)
    }

    // MARK: - Sendable Tests

    @Test
    func `LinkingState is Sendable`() {
        let state: any Sendable = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: 600
        )

        #expect(state is LinkingState)
    }

    // MARK: - Multiple Candidates Tests

    @Test
    func `LinkingState with multiple candidates`() {
        let candidates = [
            Candidate(userId: "user-1", email: "a@example.com", phone: nil, hasPassword: true, isEmailVerified: true, isPhoneVerified: false),
            Candidate(userId: "user-2", email: "b@example.com", phone: nil, hasPassword: true, isEmailVerified: true, isPhoneVerified: false),
            Candidate(userId: "user-3", email: "c@example.com", phone: "+111", hasPassword: false, isEmailVerified: true, isPhoneVerified: true)
        ]

        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "multi"),
            candidates: candidates,
            provider: .google,
            ttl: 600
        )

        #expect(state.candidates.count == 3)
        #expect(state.candidates[0].userId == "user-1")
        #expect(state.candidates[1].userId == "user-2")
        #expect(state.candidates[2].userId == "user-3")
    }

    @Test
    func `LinkingState with empty candidates`() {
        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "empty"),
            candidates: [],
            provider: .google,
            ttl: 600
        )

        #expect(state.candidates.isEmpty)
    }

    // MARK: - TTL Variations

    @Test
    func `LinkingState with short TTL (1 minute)`() {
        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: 60
        )

        // Should expire in about 60 seconds
        let expectedExpiration = state.createdAt.addingTimeInterval(60)
        #expect(abs(state.expiresAt.timeIntervalSince(expectedExpiration)) < 1)
    }

    @Test
    func `LinkingState with long TTL (1 hour)`() {
        let state = LinkingState(
            federatedIdentifier: .federated(.google, userId: "123"),
            candidates: [],
            provider: .google,
            ttl: 3600
        )

        // Should expire in about 1 hour
        let expectedExpiration = state.createdAt.addingTimeInterval(3600)
        #expect(abs(state.expiresAt.timeIntervalSince(expectedExpiration)) < 1)
    }
}

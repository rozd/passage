import Testing
import Foundation
@testable import Passage

/// The `PasskeyChallenge` DTO crosses the service → store boundary. It carries
/// the raw challenge bytes (which the store SHA-256-hashes before persisting),
/// the ceremony kind, and the absolute expiry. These tests pin down field
/// semantics, Sendable conformance, and the interaction with the store helper.
@Suite(.tags(.unit))
struct `PasskeyChallenge DTO Tests` {

    @Test
    func `Initialization preserves all fields`() {
        let bytes = Data([0x01, 0x02, 0x03, 0x04])
        let expiresAt = Date(timeIntervalSince1970: 10_000)
        let challenge = PasskeyChallenge(
            bytes: bytes,
            kind: .registration,
            expiresAt: expiresAt
        )

        #expect(challenge.bytes == bytes)
        #expect(challenge.kind == .registration)
        #expect(challenge.expiresAt == expiresAt)
    }

    @Test
    func `Kind is carried verbatim`() {
        let registration = PasskeyChallenge(
            bytes: Data("r".utf8),
            kind: .registration,
            expiresAt: Date()
        )
        let authentication = PasskeyChallenge(
            bytes: Data("a".utf8),
            kind: .authentication,
            expiresAt: Date()
        )

        #expect(registration.kind == .registration)
        #expect(authentication.kind == .authentication)
    }

    @Test
    func `Empty bytes are allowed (store rejects separately)`() {
        let challenge = PasskeyChallenge(
            bytes: Data(),
            kind: .registration,
            expiresAt: Date()
        )
        #expect(challenge.bytes.isEmpty)
    }

    @Test
    func `PasskeyChallenge is Sendable`() {
        let _: any Sendable = PasskeyChallenge(
            bytes: Data(),
            kind: .registration,
            expiresAt: Date()
        )
        #expect(Bool(true))
    }

    // The store owns hashing. Asserting here that the DTO doesn't accidentally
    // expose the hash, so tests that expect bytes-only won't drift later.
    @Test
    func `DTO exposes raw bytes, not a hash`() {
        let bytes = Data([0xAB, 0xCD, 0xEF])
        let challenge = PasskeyChallenge(bytes: bytes, kind: .registration, expiresAt: Date())
        #expect(challenge.bytes == bytes)
        #expect(challenge.bytes != Data(bytes.sha256Hex.utf8))
    }
}

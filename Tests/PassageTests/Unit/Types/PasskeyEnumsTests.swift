import Testing
import Foundation
@testable import Passage

/// Coverage for every `RawRepresentable` enum exposed by `Types/Passkey/WebAuthn.swift`.
///
/// Each of these enums uses a `.unknown(String)` (or `.unknown(Int)` analogue)
/// fallback case so that unknown W3C extensions don't crash decoding. The tests
/// here pin down:
/// - Every known raw value round-trips.
/// - Unknown raw values land in `.unknown(...)` carrying the original string.
/// - Codable round-trips preserve the value (including `.unknown`).
///
/// `COSEAlgorithmIdentifier` uses an `Int` raw value with no unknown case; its
/// tests cover the ↔ raw-value mapping and the COSE identifiers Passage ships.
@Suite(.tags(.unit))
struct `Passkey Enums Tests` {

    // MARK: - AuthenticatorTransport

    @Test(arguments: [
            ("usb", AuthenticatorTransport.usb),
            ("nfc", .nfc),
            ("ble", .ble),
            ("smart-card", .smartcard),
            ("internal", .internal),
            ("hybrid", .hybrid),
        ] as [(String, AuthenticatorTransport)])
    func `AuthenticatorTransport round-trips every known case`(raw: String, expected: AuthenticatorTransport) throws {
        #expect(AuthenticatorTransport(rawValue: raw) == expected)
        #expect(expected.rawValue == raw)
    }

    @Test
    func `AuthenticatorTransport decodes unknown raw value as .unknown`() throws {
        let value = AuthenticatorTransport(rawValue: "future-transport")
        if case .unknown(let s) = value {
            #expect(s == "future-transport")
        } else {
            Issue.record("expected .unknown, got \(value)")
        }
        #expect(value.rawValue == "future-transport")
    }

    @Test
    func `AuthenticatorTransport Codable survives JSON round-trip`() throws {
        let original: [AuthenticatorTransport] = [.usb, .ble, .unknown("xyz")]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([AuthenticatorTransport].self, from: data)
        #expect(decoded == original)
    }

    // MARK: - UserVerificationRequirement

    @Test(arguments: [
            ("required", UserVerificationRequirement.required),
            ("preferred", .preferred),
            ("discouraged", .discouraged),
        ] as [(String, UserVerificationRequirement)])
    func `UserVerificationRequirement known cases`(raw: String, expected: UserVerificationRequirement) {
        #expect(UserVerificationRequirement(rawValue: raw) == expected)
        #expect(expected.rawValue == raw)
    }

    @Test
    func `UserVerificationRequirement unknown raw value`() {
        let value = UserVerificationRequirement(rawValue: "mandatory-in-2030")
        if case .unknown(let s) = value {
            #expect(s == "mandatory-in-2030")
        } else {
            Issue.record("expected .unknown")
        }
    }

    // MARK: - AttestationConveyancePreference

    @Test(arguments: [
            ("none", AttestationConveyancePreference.none),
            ("direct", .direct),
            ("indirect", .indirect),
            ("enterprise", .enterprise),
        ] as [(String, AttestationConveyancePreference)])
    func `AttestationConveyancePreference known cases`(raw: String, expected: AttestationConveyancePreference) {
        #expect(AttestationConveyancePreference(rawValue: raw) == expected)
        #expect(expected.rawValue == raw)
    }

    @Test
    func `AttestationConveyancePreference unknown raw value`() {
        let value = AttestationConveyancePreference(rawValue: "exotic")
        if case .unknown(let s) = value {
            #expect(s == "exotic")
        } else {
            Issue.record("expected .unknown")
        }
    }

    // MARK: - PasskeyChallengeKind

    @Test
    func `PasskeyChallengeKind round-trips its two cases`() throws {
        #expect(PasskeyChallengeKind(rawValue: "registration") == .registration)
        #expect(PasskeyChallengeKind(rawValue: "authentication") == .authentication)
        #expect(PasskeyChallengeKind.registration.rawValue == "registration")
        #expect(PasskeyChallengeKind.authentication.rawValue == "authentication")
    }

    @Test
    func `PasskeyChallengeKind rejects unknown raw values`() {
        #expect(PasskeyChallengeKind(rawValue: "verification") == nil)
    }

    // MARK: - COSEAlgorithmIdentifier

    @Test(arguments: [
            (COSEAlgorithmIdentifier.ES256, -7),
            (.EdDSA, -8),
            (.ESP256, -9),
            (.ES384, -35),
            (.ES512, -36),
            (.PS256, -37),
            (.PS384, -38),
            (.PS512, -39),
            (.ESP384, -51),
            (.ESP512, -52),
            (.RS256, -257),
            (.RS384, -258),
            (.RS512, -259),
            (.RS1, -65535),
        ] as [(COSEAlgorithmIdentifier, Int)])
    func `COSEAlgorithmIdentifier known COSE identifiers`(alg: COSEAlgorithmIdentifier, expectedRaw: Int) {
        #expect(alg.rawValue == expectedRaw)
        #expect(COSEAlgorithmIdentifier(rawValue: expectedRaw) == alg)
    }

    @Test
    func `COSEAlgorithmIdentifier JSON encodes as bare integer`() throws {
        let data = try JSONEncoder().encode(COSEAlgorithmIdentifier.ES256)
        let text = String(data: data, encoding: .utf8)
        #expect(text == "-7")
    }

    @Test
    func `COSEAlgorithmIdentifier decodes from integer`() throws {
        let data = "-257".data(using: .utf8)!
        let alg = try JSONDecoder().decode(COSEAlgorithmIdentifier.self, from: data)
        #expect(alg == .RS256)
    }

    @Test
    func `COSEAlgorithmIdentifier returns nil for unknown raw value`() {
        #expect(COSEAlgorithmIdentifier(rawValue: 99) == nil)
    }

    // MARK: - Sendable

    @Test
    func `All passkey enums are Sendable`() {
        let _: any Sendable = AuthenticatorTransport.usb
        let _: any Sendable = UserVerificationRequirement.preferred
        let _: any Sendable = AttestationConveyancePreference.none
        let _: any Sendable = PasskeyChallengeKind.registration
        let _: any Sendable = COSEAlgorithmIdentifier.ES256
        #expect(Bool(true))
    }
}

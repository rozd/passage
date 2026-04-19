import Testing
import Foundation
@testable import Passage

/// `PasskeyCredential` is the verified-credential DTO produced by
/// `PasskeyService.finishRegistration(...)` and handed to
/// `PasskeyCredentialStore.createPasskeyCredential(for:from:)`. These tests
/// pin down the field surface, optional-field handling (AAGUID / attestation
/// format can be `nil` because `swift-webauthn` doesn't expose them), and
/// Sendable conformance.
@Suite("PasskeyCredential DTO Tests", .tags(.unit))
struct PasskeyCredentialTests {

    @Test("Initialization with every field populated")
    func initializationFull() {
        let credential = PasskeyCredential(
            credentialID: "AAEC",
            publicKey: Data([0xA0, 0xA1]),
            signCount: 42,
            uvInitialized: true,
            transports: [.internal, .hybrid],
            backupEligible: true,
            isBackedUp: false,
            aaguid: "00000000-0000-0000-0000-000000000000",
            attestationFormat: "packed"
        )

        #expect(credential.credentialID == "AAEC")
        #expect(credential.publicKey == Data([0xA0, 0xA1]))
        #expect(credential.signCount == 42)
        #expect(credential.uvInitialized == true)
        #expect(credential.transports == [.internal, .hybrid])
        #expect(credential.backupEligible == true)
        #expect(credential.isBackedUp == false)
        #expect(credential.aaguid == "00000000-0000-0000-0000-000000000000")
        #expect(credential.attestationFormat == "packed")
    }

    @Test("Initialization with nil AAGUID + attestationFormat (swift-webauthn default)")
    func initializationWithNilOptionalFields() {
        // The default backend currently returns nil for both — the type must
        // accept that without special-casing.
        let credential = PasskeyCredential(
            credentialID: "id",
            publicKey: Data(),
            signCount: 0,
            uvInitialized: false,
            transports: [],
            backupEligible: false,
            isBackedUp: false,
            aaguid: nil,
            attestationFormat: nil
        )

        #expect(credential.aaguid == nil)
        #expect(credential.attestationFormat == nil)
    }

    @Test("Empty transports are preserved as empty array")
    func emptyTransports() {
        let credential = PasskeyCredential(
            credentialID: "id",
            publicKey: Data(),
            signCount: 0,
            uvInitialized: false,
            transports: [],
            backupEligible: false,
            isBackedUp: false,
            aaguid: nil,
            attestationFormat: nil
        )
        #expect(credential.transports.isEmpty)
    }

    @Test("Unusual signCount values (0, UInt32.max) are preserved")
    func signCountEdgeValues() {
        let zero = PasskeyCredential(
            credentialID: "a",
            publicKey: Data(),
            signCount: 0,
            uvInitialized: false,
            transports: [],
            backupEligible: false,
            isBackedUp: false,
            aaguid: nil,
            attestationFormat: nil
        )
        let max = PasskeyCredential(
            credentialID: "b",
            publicKey: Data(),
            signCount: UInt32.max,
            uvInitialized: false,
            transports: [],
            backupEligible: false,
            isBackedUp: false,
            aaguid: nil,
            attestationFormat: nil
        )
        #expect(zero.signCount == 0)
        #expect(max.signCount == UInt32.max)
    }

    @Test("Backup flags are orthogonal (BE + BS can vary independently)")
    func backupFlagsAreOrthogonal() {
        let cases: [(Bool, Bool)] = [
            (false, false), (true, false), (true, true), (false, true),
        ]
        for (be, bs) in cases {
            let credential = PasskeyCredential(
                credentialID: "id",
                publicKey: Data(),
                signCount: 0,
                uvInitialized: false,
                transports: [],
                backupEligible: be,
                isBackedUp: bs,
                aaguid: nil,
                attestationFormat: nil
            )
            #expect(credential.backupEligible == be)
            #expect(credential.isBackedUp == bs)
        }
    }

    @Test("PasskeyCredential is Sendable")
    func isSendable() {
        let _: any Sendable = PasskeyCredential(
            credentialID: "",
            publicKey: Data(),
            signCount: 0,
            uvInitialized: false,
            transports: [],
            backupEligible: false,
            isBackedUp: false,
            aaguid: nil,
            attestationFormat: nil
        )
        #expect(Bool(true))
    }
}

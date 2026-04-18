import Testing
import Foundation
@testable import Passage

/// `Data.base64URLEncodedString` and `Data.init?(base64URLEncoded:)` are
/// internal helpers consumed by the Codable implementations of
/// `PublicKeyCredentialUserEntity` (and by any test fixtures producing
/// WebAuthn-shaped JSON). The helpers matter because WebAuthn JSON
/// serialization requires base64url (no `+`, `/`, or `=` padding).
@Suite("Data base64url Helpers", .tags(.unit))
struct DataBase64URLTests {

    @Test("Encoding strips + / = from standard base64")
    func encodingStripsURLUnsafeCharacters() {
        // Bytes chosen so standard base64 produces `+`, `/`, and trailing `=`.
        // Standard base64("ÿÿ?") = "//8/"
        // Standard base64("foob") = "Zm9vYg=="
        let a = Data([0xFF, 0xFF, 0x3F])
        let b = Data("foob".utf8)

        #expect(a.base64URLEncodedString == "__8_")
        #expect(b.base64URLEncodedString == "Zm9vYg")
    }

    @Test("Encoded string never contains URL-unsafe characters")
    func encodedStringIsURLSafe() {
        for _ in 0..<32 {
            let bytes = Data((0..<Int.random(in: 1...64)).map { _ in UInt8.random(in: 0...255) })
            let encoded = bytes.base64URLEncodedString
            #expect(!encoded.contains("+"))
            #expect(!encoded.contains("/"))
            #expect(!encoded.contains("="))
        }
    }

    @Test("Empty data encodes to empty string")
    func emptyDataEncodesToEmptyString() {
        #expect(Data().base64URLEncodedString == "")
    }

    @Test("Decoding accepts URL-safe input")
    func decodingAcceptsURLSafeInput() {
        #expect(Data(base64URLEncoded: "__8_") == Data([0xFF, 0xFF, 0x3F]))
        #expect(Data(base64URLEncoded: "Zm9vYg") == Data("foob".utf8))
    }

    @Test("Decoding accepts input regardless of missing padding")
    func decodingAcceptsUnpaddedInput() {
        // Three of the four possible padding counts (0, 1, 2 trailing =)
        // when they're omitted from the URL-encoded form.
        #expect(Data(base64URLEncoded: "YQ") == Data("a".utf8))      // would be "YQ=="
        #expect(Data(base64URLEncoded: "YWI") == Data("ab".utf8))    // would be "YWI="
        #expect(Data(base64URLEncoded: "YWJj") == Data("abc".utf8))  // no padding needed
    }

    @Test("Round-trip preserves random bytes")
    func roundTripRandomBytes() {
        for _ in 0..<16 {
            let original = Data((0..<128).map { _ in UInt8.random(in: 0...255) })
            let decoded = Data(base64URLEncoded: original.base64URLEncodedString)
            #expect(decoded == original)
        }
    }

    @Test("Decoding returns nil for plainly invalid input")
    func decodingReturnsNilForInvalid() {
        // Space and exclamation aren't in the base64url alphabet and aren't
        // reinterpreted by the helper's `+/_` substitutions.
        #expect(Data(base64URLEncoded: "not valid!") == nil)
    }

    @Test("Encoding matches WebAuthn wire format")
    func encodingMatchesWebAuthnWire() {
        // A test vector from W3C §5.1 examples: 32-byte challenge like
        // [0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8] encodes as "oaKjpKWmp6g".
        let challenge = Data([0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8])
        #expect(challenge.base64URLEncodedString == "oaKjpKWmp6g")
    }
}

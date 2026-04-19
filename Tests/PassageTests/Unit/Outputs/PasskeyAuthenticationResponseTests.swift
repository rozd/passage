import Testing
import Foundation
import Vapor
@testable import Passage

/// `PasskeyAuthenticationResponse` is the 200-OK body returned from
/// `POST /passkey/authenticate/finish`. The JSON shape is load-bearing: the
/// browser-side JavaScript in `passkey-authenticate-minimalism.leaf` reads the
/// `code` field and uses it to build the post-auth redirect URL (matching the
/// OAuth exchange-code pattern).
@Suite("PasskeyAuthenticationResponse Tests", .tags(.unit))
struct PasskeyAuthenticationResponseTests {

    @Test("Initialization preserves code")
    func initialization() {
        let response = PasskeyAuthenticationResponse(code: "exchange-abc-123")
        #expect(response.code == "exchange-abc-123")
    }

    @Test("JSON encoding uses the `code` key")
    func jsonEncodingKey() throws {
        let response = PasskeyAuthenticationResponse(code: "xyz")
        let data = try JSONEncoder().encode(response)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["code"] as? String == "xyz")
    }

    @Test("Codable round-trip preserves code")
    func codableRoundTrip() throws {
        let original = PasskeyAuthenticationResponse(code: "roundtrip-code")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PasskeyAuthenticationResponse.self, from: data)
        #expect(decoded.code == original.code)
    }

    @Test("Conforms to Vapor Content (Codable + Sendable + encoders)")
    func conformsToContent() {
        let _: any Content = PasskeyAuthenticationResponse(code: "c")
        let _: any Sendable = PasskeyAuthenticationResponse(code: "c")
        #expect(Bool(true))
    }

    @Test("Empty code is permitted at the type layer")
    func emptyCodeAllowed() {
        // Higher-level layers guarantee the exchange token is non-empty.
        let response = PasskeyAuthenticationResponse(code: "")
        #expect(response.code.isEmpty)
    }
}

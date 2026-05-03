import Testing
import Foundation
import Vapor
@testable import Passage

/// `PasskeyAuthenticationResponse` is the 200-OK body returned from
/// `POST /passkey/authenticate/finish`. The JSON shape is load-bearing: the
/// browser-side JavaScript in `passkey-authentication-minimalism.leaf` reads the
/// `code` field and uses it to build the post-auth redirect URL (matching the
/// OAuth exchange-code pattern).
@Suite(.tags(.unit))
struct `PasskeyAuthenticationResponse Tests` {

    @Test
    func `Initialization preserves code`() {
        let response = PasskeyAuthenticationResponse(code: "exchange-abc-123")
        #expect(response.code == "exchange-abc-123")
    }

    @Test
    func `JSON encoding uses the 'code' key`() throws {
        let response = PasskeyAuthenticationResponse(code: "xyz")
        let data = try JSONEncoder().encode(response)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["code"] as? String == "xyz")
    }

    @Test
    func `Codable round-trip preserves code`() throws {
        let original = PasskeyAuthenticationResponse(code: "roundtrip-code")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PasskeyAuthenticationResponse.self, from: data)
        #expect(decoded.code == original.code)
    }

    @Test
    func `Conforms to Vapor Content (Codable + Sendable + encoders)`() {
        let _: any Content = PasskeyAuthenticationResponse(code: "c")
        let _: any Sendable = PasskeyAuthenticationResponse(code: "c")
        #expect(Bool(true))
    }

    @Test
    func `Empty code is permitted at the type layer`() {
        // Higher-level layers guarantee the exchange token is non-empty.
        let response = PasskeyAuthenticationResponse(code: "")
        #expect(response.code.isEmpty)
    }
}

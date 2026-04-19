import Testing
import Foundation
import Vapor
@testable import Passage

/// `PasskeyRegistrationResponse` is the tiny response body returned on
/// `201 Created` from both `POST /passkey/signup/finish` and
/// `POST /passkey/register/finish`. The JSON shape is load-bearing: the
/// browser-side JavaScript in `passkey-signup-minimalism.leaf` relies on
/// the `credentialID` field name.
@Suite("PasskeyRegistrationResponse Tests", .tags(.unit))
struct PasskeyRegistrationResponseTests {

    @Test("Initialization preserves credentialID")
    func initialization() {
        let response = PasskeyRegistrationResponse(credentialID: "abc-123")
        #expect(response.credentialID == "abc-123")
    }

    @Test("JSON encoding uses the `credentialID` key")
    func jsonEncodingKey() throws {
        let response = PasskeyRegistrationResponse(credentialID: "xyz")
        let data = try JSONEncoder().encode(response)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["credentialID"] as? String == "xyz")
    }

    @Test("Codable round-trip preserves credentialID")
    func codableRoundTrip() throws {
        let original = PasskeyRegistrationResponse(credentialID: "roundtrip-id")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PasskeyRegistrationResponse.self, from: data)
        #expect(decoded.credentialID == original.credentialID)
    }

    @Test("Conforms to Vapor Content (Codable + Sendable + encoders)")
    func conformsToContent() {
        let _: any Content = PasskeyRegistrationResponse(credentialID: "c")
        let _: any Sendable = PasskeyRegistrationResponse(credentialID: "c")
        #expect(Bool(true))
    }

    @Test("Empty credentialID is permitted at the type layer")
    func emptyCredentialIDAllowed() {
        // The type itself doesn't validate. Higher-level layers are responsible
        // for ensuring a real ID is present.
        let response = PasskeyRegistrationResponse(credentialID: "")
        #expect(response.credentialID.isEmpty)
    }
}

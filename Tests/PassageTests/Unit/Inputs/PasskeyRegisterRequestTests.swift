import Testing
import Foundation
import Vapor
@testable import Passage

@Suite("PasskeyRegisterRequest Tests", .tags(.unit, .passkey))
struct PasskeyRegisterRequestTests {

    // MARK: - Initialization

    @Test("Init with displayName stores value")
    func initWithDisplayName() {
        let req = PasskeyRegisterRequest(displayName: "Alice")
        #expect(req.displayName == "Alice")
    }

    @Test("Default init has nil displayName")
    func defaultInitHasNilDisplayName() {
        let req = PasskeyRegisterRequest()
        #expect(req.displayName == nil)
    }

    @Test("Init with explicit nil displayName stores nil")
    func initWithNilDisplayName() {
        let req = PasskeyRegisterRequest(displayName: nil)
        #expect(req.displayName == nil)
    }

    // MARK: - JSON Decoding

    @Test("Decodes from JSON with displayName")
    func decodesWithDisplayName() throws {
        let json = #"{"displayName":"Alice"}"#
        let req = try JSONDecoder().decode(PasskeyRegisterRequest.self, from: Data(json.utf8))
        #expect(req.displayName == "Alice")
    }

    @Test("Decodes from empty JSON object as nil displayName")
    func decodesEmptyJSON() throws {
        let json = #"{}"#
        let req = try JSONDecoder().decode(PasskeyRegisterRequest.self, from: Data(json.utf8))
        #expect(req.displayName == nil)
    }

    @Test("Decodes from JSON with explicit null displayName")
    func decodesNullDisplayName() throws {
        let json = #"{"displayName":null}"#
        let req = try JSONDecoder().decode(PasskeyRegisterRequest.self, from: Data(json.utf8))
        #expect(req.displayName == nil)
    }

    @Test("Decodes display name with special characters")
    func decodesDisplayNameWithSpecialChars() throws {
        let json = #"{"displayName":"José Müller"}"#
        let req = try JSONDecoder().decode(PasskeyRegisterRequest.self, from: Data(json.utf8))
        #expect(req.displayName == "José Müller")
    }

    // MARK: - Sendable

    @Test("PasskeyRegisterRequest conforms to Sendable")
    func conformsToSendable() {
        func assertSendable<T: Sendable>(_ value: T) {}
        assertSendable(PasskeyRegisterRequest(displayName: "Alice"))
        assertSendable(PasskeyRegisterRequest())
    }
}

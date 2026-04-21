import Testing
import Foundation
import Vapor
@testable import Passage

@Suite(.tags(.unit, .passkey))
struct `PasskeyRegisterRequest Tests` {

    // MARK: - Initialization

    @Test
    func `Init with displayName stores value`() {
        let req = PasskeyRegisterRequest(displayName: "Alice")
        #expect(req.displayName == "Alice")
    }

    @Test
    func `Default init has nil displayName`() {
        let req = PasskeyRegisterRequest()
        #expect(req.displayName == nil)
    }

    @Test
    func `Init with explicit nil displayName stores nil`() {
        let req = PasskeyRegisterRequest(displayName: nil)
        #expect(req.displayName == nil)
    }

    // MARK: - JSON Decoding

    @Test
    func `Decodes from JSON with displayName`() throws {
        let json = #"{"displayName":"Alice"}"#
        let req = try JSONDecoder().decode(PasskeyRegisterRequest.self, from: Data(json.utf8))
        #expect(req.displayName == "Alice")
    }

    @Test
    func `Decodes from empty JSON object as nil displayName`() throws {
        let json = #"{}"#
        let req = try JSONDecoder().decode(PasskeyRegisterRequest.self, from: Data(json.utf8))
        #expect(req.displayName == nil)
    }

    @Test
    func `Decodes from JSON with explicit null displayName`() throws {
        let json = #"{"displayName":null}"#
        let req = try JSONDecoder().decode(PasskeyRegisterRequest.self, from: Data(json.utf8))
        #expect(req.displayName == nil)
    }

    @Test
    func `Decodes display name with special characters`() throws {
        let json = #"{"displayName":"José Müller"}"#
        let req = try JSONDecoder().decode(PasskeyRegisterRequest.self, from: Data(json.utf8))
        #expect(req.displayName == "José Müller")
    }

    // MARK: - Sendable

    @Test
    func `PasskeyRegisterRequest conforms to Sendable`() {
        func assertSendable<T: Sendable>(_ value: T) {}
        assertSendable(PasskeyRegisterRequest(displayName: "Alice"))
        assertSendable(PasskeyRegisterRequest())
    }
}

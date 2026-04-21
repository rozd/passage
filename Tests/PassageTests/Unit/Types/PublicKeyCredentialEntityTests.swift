import Testing
import Foundation
@testable import Passage

/// Tests for `PublicKeyCredentialEntity` conformers (`PublicKeyCredentialRpEntity`
/// and `PublicKeyCredentialUserEntity`). The user entity has a custom Codable
/// that base64url-encodes its binary `id` field on the wire — that's the thing
/// most worth pinning down.
@Suite(.tags(.unit))
struct `PublicKeyCredential Entity Tests` {

    // MARK: - PublicKeyCredentialRpEntity

    @Test
    func `RpEntity initialization preserves name and id`() {
        let rp = PublicKeyCredentialRpEntity(name: "Example Corp", id: "example.com")
        #expect(rp.name == "Example Corp")
        #expect(rp.id == "example.com")
    }

    @Test
    func `RpEntity Codable round-trip preserves both fields as plain strings`() throws {
        let rp = PublicKeyCredentialRpEntity(name: "Acme", id: "acme.io")
        let data = try JSONEncoder().encode(rp)
        let decoded = try JSONDecoder().decode(PublicKeyCredentialRpEntity.self, from: data)
        #expect(decoded == rp)
    }

    @Test
    func `RpEntity JSON shape matches W3C dictionary layout`() throws {
        let rp = PublicKeyCredentialRpEntity(name: "Acme", id: "acme.io")
        let data = try JSONEncoder().encode(rp)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["name"] as? String == "Acme")
        #expect(json["id"] as? String == "acme.io")
    }

    @Test
    func `RpEntity equality`() {
        let a = PublicKeyCredentialRpEntity(name: "A", id: "a.com")
        let b = PublicKeyCredentialRpEntity(name: "A", id: "a.com")
        let c = PublicKeyCredentialRpEntity(name: "A", id: "different.com")
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - PublicKeyCredentialUserEntity

    @Test
    func `UserEntity initialization preserves all fields including raw id bytes`() {
        let id = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let user = PublicKeyCredentialUserEntity(
            name: "alice@example.com",
            id: id,
            displayName: "Alice"
        )
        #expect(user.name == "alice@example.com")
        #expect(user.id == id)
        #expect(user.displayName == "Alice")
    }

    @Test
    func `UserEntity encodes id as base64url (no + / = padding)`() throws {
        // Bytes chosen so plain base64 would produce `+`, `/`, and `=` characters.
        // Standard base64(ÿÿ?) = //8/ ; base64url should be "__8_" without padding.
        let id = Data([0xFF, 0xFF, 0x3F])
        let user = PublicKeyCredentialUserEntity(name: "n", id: id, displayName: "d")
        let data = try JSONEncoder().encode(user)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encodedId = try #require(json["id"] as? String)
        #expect(!encodedId.contains("+"))
        #expect(!encodedId.contains("/"))
        #expect(!encodedId.contains("="))
    }

    @Test
    func `UserEntity Codable JSON round-trip preserves binary id`() throws {
        let id = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let original = PublicKeyCredentialUserEntity(
            name: "bob@example.com",
            id: id,
            displayName: "Bob"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PublicKeyCredentialUserEntity.self, from: data)
        #expect(decoded.name == original.name)
        #expect(decoded.id == original.id)
        #expect(decoded.displayName == original.displayName)
    }

    @Test
    func `UserEntity decoding fails for non-base64url id`() throws {
        // The letters/digits here are base64url-valid; the space and exclamation
        // are not, which should make `Data(base64URLEncoded:)` return nil and
        // trigger a DecodingError.
        let bad = #"{"name":"n","id":"not base64url!","displayName":"d"}"#.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(PublicKeyCredentialUserEntity.self, from: bad)
        }
    }

    @Test
    func `UserEntity equality compares every field`() {
        let a = PublicKeyCredentialUserEntity(
            name: "a", id: Data([0x01]), displayName: "A"
        )
        let sameAsA = PublicKeyCredentialUserEntity(
            name: "a", id: Data([0x01]), displayName: "A"
        )
        let diffId = PublicKeyCredentialUserEntity(
            name: "a", id: Data([0x02]), displayName: "A"
        )
        #expect(a == sameAsA)
        #expect(a != diffId)
    }

    // MARK: - Base protocol

    @Test
    func `Both entity types conform to PublicKeyCredentialEntity`() {
        let rp: any PublicKeyCredentialEntity = PublicKeyCredentialRpEntity(name: "n", id: "i")
        let user: any PublicKeyCredentialEntity = PublicKeyCredentialUserEntity(
            name: "n", id: Data(), displayName: "d"
        )
        #expect(rp.name == "n")
        #expect(user.name == "n")
    }

    @Test
    func `Both entity types are Sendable`() {
        let _: any Sendable = PublicKeyCredentialRpEntity(name: "n", id: "i")
        let _: any Sendable = PublicKeyCredentialUserEntity(
            name: "n", id: Data(), displayName: "d"
        )
        #expect(Bool(true))
    }
}

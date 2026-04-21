import Testing
import Foundation
@testable import Passage

@Suite
struct `RandomGenerator Tests` {

    // MARK: - DefaultRandomGenerator Tests

    @Test
    func `DefaultRandomGenerator generateRandomString creates non-empty string`() {
        let generator = DefaultRandomGenerator()
        let randomString = generator.generateRandomString(count: 16)

        #expect(!randomString.isEmpty)
    }

    @Test(arguments: [
        8, 16, 32, 64
    ])
    func `DefaultRandomGenerator generateRandomString with different counts`(count: Int) {
        let generator = DefaultRandomGenerator()
        let randomString = generator.generateRandomString(count: count)

        // Base64 encoded strings have length roughly 4/3 of input bytes
        #expect(randomString.count > 0)
    }

    @Test
    func `DefaultRandomGenerator generateRandomString produces different values`() {
        let generator = DefaultRandomGenerator()
        let string1 = generator.generateRandomString(count: 16)
        let string2 = generator.generateRandomString(count: 16)

        #expect(string1 != string2)
    }

    @Test
    func `DefaultRandomGenerator generateOpaqueToken creates non-empty token`() {
        let generator = DefaultRandomGenerator()
        let token = generator.generateOpaqueToken()

        #expect(!token.isEmpty)
    }

    @Test
    func `DefaultRandomGenerator generateOpaqueToken produces different values`() {
        let generator = DefaultRandomGenerator()
        let token1 = generator.generateOpaqueToken()
        let token2 = generator.generateOpaqueToken()

        #expect(token1 != token2)
    }

    @Test
    func `DefaultRandomGenerator hashOpaqueToken creates consistent hash`() {
        let generator = DefaultRandomGenerator()
        let token = "test_token"
        let hash1 = generator.hashOpaqueToken(token: token)
        let hash2 = generator.hashOpaqueToken(token: token)

        #expect(hash1 == hash2)
    }

    @Test
    func `DefaultRandomGenerator hashOpaqueToken creates different hashes for different tokens`() {
        let generator = DefaultRandomGenerator()
        let hash1 = generator.hashOpaqueToken(token: "token1")
        let hash2 = generator.hashOpaqueToken(token: "token2")

        #expect(hash1 != hash2)
    }

    @Test
    func `DefaultRandomGenerator hashOpaqueToken produces 64-character hex string`() {
        let generator = DefaultRandomGenerator()
        let hash = generator.hashOpaqueToken(token: "test")

        // SHA256 produces 64 hex characters
        #expect(hash.count == 64)
    }

    @Test
    func `DefaultRandomGenerator hashOpaqueToken produces hex characters only`() {
        let generator = DefaultRandomGenerator()
        let hash = generator.hashOpaqueToken(token: "test")

        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdef")
        let hashCharacterSet = CharacterSet(charactersIn: hash)
        #expect(hashCharacterSet.isSubset(of: hexCharacterSet))
    }

    @Test
    func `DefaultRandomGenerator generateVerificationCode creates code of correct length`() {
        let generator = DefaultRandomGenerator()
        let code = generator.generateVerificationCode(length: 6)

        #expect(code.count == 6)
    }

    @Test(arguments: [
        4, 6, 8, 10
    ])
    func `DefaultRandomGenerator generateVerificationCode with different lengths`(length: Int) {
        let generator = DefaultRandomGenerator()
        let code = generator.generateVerificationCode(length: length)

        #expect(code.count == length)
    }

    @Test
    func `DefaultRandomGenerator generateVerificationCode produces different values`() {
        let generator = DefaultRandomGenerator()
        let code1 = generator.generateVerificationCode(length: 6)
        let code2 = generator.generateVerificationCode(length: 6)

        // Very high probability codes are different
        #expect(code1 != code2)
    }

    @Test
    func `DefaultRandomGenerator generateVerificationCode excludes confusing characters`() {
        let generator = DefaultRandomGenerator()
        let code = generator.generateVerificationCode(length: 100) // Large sample

        // Should not contain 0, O, 1, I (based on actual implementation)
        #expect(!code.contains("0"))
        #expect(!code.contains("O"))
        #expect(!code.contains("1"))
        #expect(!code.contains("I"))
    }

    @Test
    func `DefaultRandomGenerator generateVerificationCode uses alphanumeric characters`() {
        let generator = DefaultRandomGenerator()
        let code = generator.generateVerificationCode(length: 100)

        let allowedCharacters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        for char in code {
            #expect(allowedCharacters.contains(char))
        }
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `DefaultRandomGenerator conforms to RandomGenerator protocol`() {
        let generator: any Passage.RandomGenerator = DefaultRandomGenerator()
        #expect(generator is DefaultRandomGenerator)
    }

    @Test
    func `RandomGenerator protocol conforms to Sendable`() {
        let generator: any Sendable = DefaultRandomGenerator()
        #expect(generator is DefaultRandomGenerator)
    }

    // MARK: - Custom RandomGenerator Implementation Tests

    struct CustomRandomGenerator: Passage.RandomGenerator {
        func generateRandomString(count: Int) -> String { "custom_random" }
        func generateOpaqueToken() -> String { "custom_token" }
        func hashOpaqueToken(token: String) -> String { "custom_hash" }
        func generateVerificationCode(length: Int) -> String { String(repeating: "X", count: length) }
    }

    @Test
    func `Custom RandomGenerator implementation can be used`() {
        let generator: any Passage.RandomGenerator = CustomRandomGenerator()

        #expect(generator.generateRandomString(count: 10) == "custom_random")
        #expect(generator.generateOpaqueToken() == "custom_token")
        #expect(generator.hashOpaqueToken(token: "test") == "custom_hash")
        #expect(generator.generateVerificationCode(length: 6) == "XXXXXX")
    }

    // MARK: - Edge Cases Tests

    @Test
    func `DefaultRandomGenerator generateVerificationCode with length 0`() {
        let generator = DefaultRandomGenerator()
        let code = generator.generateVerificationCode(length: 0)

        #expect(code.isEmpty)
    }

    @Test
    func `DefaultRandomGenerator generateRandomString with count 0`() {
        let generator = DefaultRandomGenerator()
        let randomString = generator.generateRandomString(count: 0)

        // Base64 of empty data is empty string
        #expect(randomString.isEmpty)
    }

    @Test
    func `DefaultRandomGenerator hashOpaqueToken with empty string`() {
        let generator = DefaultRandomGenerator()
        let hash = generator.hashOpaqueToken(token: "")

        // Even empty string should produce valid SHA256 hash
        #expect(hash.count == 64)
    }

    // MARK: - Integration Tests

    @Test
    func `DefaultRandomGenerator token and hash workflow`() {
        let generator = DefaultRandomGenerator()

        // Generate token
        let token = generator.generateOpaqueToken()
        #expect(!token.isEmpty)

        // Hash the token
        let hash = generator.hashOpaqueToken(token: token)
        #expect(hash.count == 64)

        // Same token produces same hash
        let hash2 = generator.hashOpaqueToken(token: token)
        #expect(hash == hash2)
    }

    @Test
    func `DefaultRandomGenerator verification code workflow`() {
        let generator = DefaultRandomGenerator()

        // Generate code
        let code = generator.generateVerificationCode(length: 6)
        #expect(code.count == 6)

        // Hash the code
        let hash = generator.hashOpaqueToken(token: code)
        #expect(hash.count == 64)

        // Verify same code produces same hash
        let hash2 = generator.hashOpaqueToken(token: code)
        #expect(hash == hash2)
    }
}

import Testing
import Foundation
@testable import Passage

@Suite
struct `JWT Configuration Tests` {

    // MARK: - JWKS Tests

    @Test
    func `JWKS initialization with JSON string`() {
        let jwksJSON = """
        {"keys":[{"kty":"RSA","kid":"test-key","use":"sig","n":"test","e":"AQAB"}]}
        """
        let jwks = Passage.Configuration.JWT.JWKS(json: jwksJSON)

        #expect(jwks.json == jwksJSON)
    }

    @Test
    func `JWKS from environment variable`() throws {
        let jwksJSON = """
        {"keys":[{"kty":"RSA","kid":"env-key"}]}
        """

        // Set environment variable
        setenv("TEST_JWKS", jwksJSON, 1)
        defer { unsetenv("TEST_JWKS") }

        let jwks = try Passage.Configuration.JWT.JWKS.environment(name: "TEST_JWKS")
        #expect(jwks.json == jwksJSON)
    }

    @Test
    func `JWKS from missing environment variable throws error`() {
        #expect(throws: PassageError.self) {
            try Passage.Configuration.JWT.JWKS.environment(name: "NONEXISTENT_JWKS")
        }
    }

    @Test
    func `JWKS from file`() throws {
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test-jwks-\(UUID().uuidString).json")

        let jwksJSON = """
        {"keys":[{"kty":"RSA","kid":"file-key"}]}
        """

        try jwksJSON.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let jwks = try Passage.Configuration.JWT.JWKS.file(path: tempFile.path)
        #expect(jwks.json == jwksJSON)
    }

    @Test
    func `JWKS from file with invalid path throws error`() {
        #expect(throws: (any Error).self) {
            try Passage.Configuration.JWT.JWKS.file(path: "/nonexistent/path/to/jwks.json")
        }
    }

    @Test
    func `JWKS from file path environment variable`() throws {
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test-jwks-env-\(UUID().uuidString).json")

        let jwksJSON = """
        {"keys":[{"kty":"RSA","kid":"env-file-key"}]}
        """

        try jwksJSON.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Set environment variable with file path
        setenv("TEST_JWKS_FILE_PATH", tempFile.path, 1)
        defer { unsetenv("TEST_JWKS_FILE_PATH") }

        let jwks = try Passage.Configuration.JWT.JWKS.fileFromEnvironment(name: "TEST_JWKS_FILE_PATH")
        #expect(jwks.json == jwksJSON)
    }

    @Test
    func `JWKS from file path with missing environment variable throws error`() {
        #expect(throws: PassageError.self) {
            try Passage.Configuration.JWT.JWKS.fileFromEnvironment(name: "NONEXISTENT_FILE_PATH")
        }
    }

    // MARK: - JWT Configuration Tests

    @Test
    func `JWT configuration initialization`() {
        let jwksJSON = """
        {"keys":[{"kty":"RSA"}]}
        """
        let jwks = Passage.Configuration.JWT.JWKS(json: jwksJSON)
        let jwt = Passage.Configuration.JWT(jwks: jwks)

        #expect(jwt.jwks.json == jwksJSON)
    }

    @Test
    func `JWT Sendable conformance`() {
        let jwks = Passage.Configuration.JWT.JWKS(json: "{}")
        let jwt = Passage.Configuration.JWT(jwks: jwks)

        let _: any Sendable = jwt
        let _: any Sendable = jwks
    }
}

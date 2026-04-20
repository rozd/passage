import Foundation
import Testing
import Vapor
import VaporTesting
import JWTKit
import XCTQueues
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 hashed-at-rest memorized secret storage
//
// SP 800-63B §5.1.1.2-w: Verifiers SHALL store memorized secrets in a form
// that is resistant to offline attacks. The concrete guard is that after a
// successful registration, the stored representation is the Bcrypt hash,
// not the plaintext password — an attacker with the database snapshot
// cannot recover the password without a per-hash brute-force.

@Suite("AAL1 memorized secret storage", .tags(.aal1, .memorizedSecret))
struct HashingTests {

    @Sendable private func configure(_ app: Application) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )
        app.queues.use(.asyncTest)

        let services = Passage.Services(
            store: Passage.OnlyForTest.InMemoryStore(),
            random: DefaultRandomGenerator(),
            emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
            phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
            federatedLogin: nil
        )

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            jwt: .init(jwks: .init(json: "{\"keys\":[]}"))
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )
    }

    @Test(
        "§5.1.1.2-w: Stored passwordHash is an offline-attack-resistant KDF output, not the plaintext",
        .tags(.aal1, .memorizedSecret, .authenticator, .integration, .shall)
    )
    func storedHashIsNotPlaintext() async throws {
        let plaintext = "plain-password-42"

        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "hashed-user",
                    "password": plaintext,
                    "confirmPassword": plaintext
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let store = app.passage.storage.services.store
            let user = try #require(try await store.users.find(byIdentifier: .username("hashed-user")))
            let storedHash = try #require(user.passwordHash,
                                          "password user must have a stored hash")

            // The stored value MUST NOT be the plaintext. Bcrypt hashes
            // begin with "$2" (modular crypt format), are ~60 chars, and
            // round-trip through Bcrypt.verify. All three checks together
            // prove the storage form resists offline attacks beyond a
            // naïve lookup.
            #expect(storedHash != plaintext,
                    "stored hash must not equal the plaintext — §5.1.1.2-w")
            #expect(storedHash.hasPrefix("$2"),
                    "stored hash must be a Bcrypt modular-crypt string")
            let verified = try Bcrypt.verify(plaintext, created: storedHash)
            #expect(verified, "stored hash must still verify the original plaintext")
        }
    }
}

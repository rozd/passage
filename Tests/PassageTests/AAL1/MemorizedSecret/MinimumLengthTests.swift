import Foundation
import Testing
import Vapor
import VaporTesting
import JWTKit
import XCTQueues
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 memorized secret minimum length
//
// SP 800-63B §5.1.1.1-a (subscriber-chosen secret) and §5.1.1.2-a (verifier
// requirement) both pin the floor at 8 characters. These tests exercise the
// registration endpoint — the only path where a subscriber *chooses* a
// memorized secret — and assert that inputs shorter than 8 characters are
// rejected before a user record is persisted.

@Suite("AAL1 memorized secret minimum length", .tags(.aal1, .memorizedSecret))
struct MinimumLengthTests {

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
        "§5.1.1.1-a: Registration rejects subscriber-chosen passwords shorter than 8 characters",
        .tags(.aal1, .memorizedSecret, .authenticator, .integration, .shall)
    )
    func subscriberChosenSecretBelow8CharsIsRejected() async throws {
        try await withApp(configure: configure) { app in
            // 7 characters — one short of the AAL1 §5.1.1.1-a floor.
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "shortpw",
                    "password": "1234567",
                    "confirmPassword": "1234567"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .badRequest,
                        "7-char password must be rejected to satisfy §5.1.1.1-a")

                // No user should have been persisted.
                let store = app.passage.storage.services.store
                let user = try await store.users.find(byIdentifier: .username("shortpw"))
                #expect(user == nil, "rejected registration must not persist a user")
            })
        }
    }

    @Test(
        "§5.1.1.2-a: Verifier rejects a password-reset submission whose new secret is shorter than 8 characters",
        .tags(.aal1, .memorizedSecret, .authenticator, .integration, .shall)
    )
    func verifierRejectsShortNewPasswordAtReset() async throws {
        try await withApp(configure: configure) { app in
            // Seed a verified email user so the reset flow has a user to act
            // on — bypasses the registration/verify mails in a single create.
            let store = app.passage.storage.services.store
            _ = try await store.users.create(
                identifier: .email("verifier@example.com"),
                with: .password("$2b$12$valid-initial-hash")
            )
            try await store.users.markEmailVerified(for: try #require(
                try await store.users.find(byIdentifier: .email("verifier@example.com"))
            ))

            // Request a reset code so we have a valid code in hand.
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": "verifier@example.com"])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Submit a new password that is one character below the §5.1.1.2-a
            // verifier floor. The code doesn't need to be valid — the verifier
            // SHALL reject the password independently of code validity.
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": "verifier@example.com",
                    "code": "ANY-CODE",
                    "newPassword": "short-7"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .badRequest,
                        "verifier must reject a 7-char new password at reset to satisfy §5.1.1.2-a")
            })
        }
    }
}

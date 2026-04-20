import Foundation
import Testing
import Vapor
import VaporTesting
import JWTKit
import XCTQueues
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - AAL1 compromised-value blocklist
//
// SP 800-63B §5.1.1.1-c: If the verifier disallows a chosen memorized secret
// because it appears on a blacklist of compromised values, the subscriber
// SHALL be required to choose a different memorized secret.
//
// The clause is conditional — it only activates once Passage opts into
// breached-password checking. The test below pins the expected public surface
// (`Passage.Configuration.PasswordPolicy.breachedPasswordBlocklist`) that the
// compliance work must land. Until that API exists the file is expected to
// fail to compile; that failure is the Phase 3 trigger, not a regression.

@Suite("AAL1 compromised-value blocklist", .tags(.aal1, .memorizedSecret))
struct BreachedPasswordTests {

    @Sendable private func configureWithBlocklist(_ app: Application) async throws {
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

        // Expected future API — see commit message for the implementation
        // gap this pins.
        let policy = Passage.Configuration.PasswordPolicy.relaxed(
            minLength: 8,
            breachedPasswordBlocklist: ["password123456"]
        )

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            jwt: .init(jwks: .init(json: "{\"keys\":[]}")),
            passwordPolicy: policy
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )
    }

    @Test(
        "§5.1.1.1-c: Blocklisted memorized secret is rejected and a different one succeeds",
        .tags(.aal1, .memorizedSecret, .authenticator, .integration, .shall)
    )
    func blocklistedSecretForcesSubscriberToChooseAnother() async throws {
        try await withApp(configure: configureWithBlocklist) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "breached-user",
                    "password": "password123456",
                    "confirmPassword": "password123456"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .badRequest,
                        "blocklisted password must be rejected to satisfy §5.1.1.1-c")
            })

            // Subscriber is required to pick a different secret — success path.
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "breached-user",
                    "password": "an-uncompromised-secret",
                    "confirmPassword": "an-uncompromised-secret"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok,
                        "a non-blocklisted replacement secret must be accepted")
            })
        }
    }

    @Test(
        "§5.1.1.2-l: Verifier compares prospective secret against the blocklist at password change",
        .tags(.aal1, .memorizedSecret, .authenticator, .integration, .shall)
    )
    func verifierChecksBlocklistAtPasswordChange() async throws {
        try await withApp(configure: configureWithBlocklist) { app in
            // Seed a verified email user so the reset flow has a target.
            let store = app.passage.storage.services.store
            _ = try await store.users.create(
                identifier: .email("change@example.com"),
                with: .password("$2b$12$initial-hash-placeholder-value")
            )
            let user = try #require(
                try await store.users.find(byIdentifier: .email("change@example.com"))
            )
            try await store.users.markEmailVerified(for: user)

            // Request reset code (we do not need to submit the real code —
            // the verifier MUST reject the blocklisted password before any
            // code check could succeed).
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": "change@example.com"])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // §5.1.1.2-l applies to both "establish" and "change" — here we
            // exercise change. Submitting the blocklisted value as the new
            // password MUST be rejected by the verifier.
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": "change@example.com",
                    "code": "ANY-CODE",
                    "newPassword": "password123456"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .badRequest,
                        "the verifier must compare the new password against the blocklist per §5.1.1.2-l")
            })
        }
    }

    private struct VaporErrorBody: Content {
        let error: Bool
        let reason: String
    }

    @Test(
        "§5.1.1.2-m: Rejection response advises the subscriber to select a different secret",
        .tags(.aal1, .memorizedSecret, .authenticator, .integration, .shall)
    )
    func rejectionAdvisesSelectingDifferentSecret() async throws {
        try await withApp(configure: configureWithBlocklist) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "advisory-user",
                    "password": "password123456",
                    "confirmPassword": "password123456"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .badRequest)

                // Vapor renders AbortError as { "error": true, "reason": "..." }
                let body = try res.content.decode(VaporErrorBody.self)
                let lowerReason = body.reason.lowercased()
                #expect(lowerReason.contains("different") || lowerReason.contains("choose") || lowerReason.contains("try"),
                        "rejection reason must advise subscriber to choose a different secret per §5.1.1.2-m — got: \(body.reason)")
            })
        }
    }

    @Test(
        "§5.1.1.2-n: Rejection response provides a non-empty reason identifying the password as the rejected input",
        .tags(.aal1, .memorizedSecret, .authenticator, .integration, .shall)
    )
    func rejectionProvidesReason() async throws {
        try await withApp(configure: configureWithBlocklist) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "reason-user",
                    "password": "password123456",
                    "confirmPassword": "password123456"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .badRequest)

                let body = try res.content.decode(VaporErrorBody.self)
                #expect(body.error == true, "response must signal an error")
                #expect(!body.reason.isEmpty,
                        "rejection must carry a non-empty reason per §5.1.1.2-n")
                #expect(body.reason.lowercased().contains("password"),
                        "reason must identify the password as the rejected input — got: \(body.reason)")
            })
        }
    }
}

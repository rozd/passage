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
        let policy = Passage.Configuration.PasswordPolicy(
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
}

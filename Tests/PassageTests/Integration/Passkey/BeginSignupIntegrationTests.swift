import JWT
import NIOFoundationCompat
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting

/// End-to-end coverage of `POST /auth/passkey/signup/begin` plus the
/// `GET` view that serves its HTML entry point. These tests pin down:
///
/// 1. The JSON contract the browser JS in `passkey-signup-minimalism.leaf`
///    relies on (base64url binary fields, nested `rp`/`user`, etc.).
/// 2. The dual-mode response pattern (`Accept: application/json` returns
///    options; HTML form submit with `Accept: text/html` and a configured
///    passkey view redirects back to that view).
/// 3. That the handler references `views.passkeySignup` (not `views.login`).
/// 4. That the orchestration forwards the identifier + displayName into the
///    `PublicKeyCredentialUserEntity` handed to the service.
/// 5. That the view context carries `signupBeginURL` / `signupFinishURL`
///    so the inline JS knows where to POST.
@Suite("Passkey Begin Signup Integration Tests", .tags(.integration, .passkey))
struct BeginSignupIntegrationTests {

    // MARK: - Configuration Helpers

    /// Sendable bag so we can reach the mock from within a `@Sendable` configure
    /// closure and still read its `.calls` from the test body after the request.
    final class Holder: @unchecked Sendable {
        var service: MockPasskeyService?
    }

    /// Defaults used across the suite: RP "example.com" on localhost, 5-minute
    /// challenge TTL. Override `passkeyService` to test failure paths or to
    /// assert what the service received.
    @Sendable private func configure(
        _ app: Application,
        passkeyService: (any Passage.PasskeyService)? = MockPasskeyService(),
        views: Passage.Configuration.Views = .init(),
        routes: Passage.Configuration.Routes = .init(),
        passkeyRoutes: Passage.Configuration.Passkey.Routes = .init(),
        includePasskeyConfig: Bool = true
    ) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
            phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
            federatedLogin: nil,
            passkey: includePasskeyConfig ? passkeyService : nil
        )

        let passkeyConfig: Passage.Configuration.Passkey = .init(
            routes: passkeyRoutes
        )

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: routes,
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: #"{"keys":[]}"#)),
            verification: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: false
            ),
            restoration: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: false
            ),
            passkey: passkeyConfig,
            views: views
        )

        try await app.passage.configure(services: services, configuration: configuration)
    }

    // MARK: - JSON wire shape

    @Test("POST begin returns options as JSON with base64url challenge when Accept: application/json")
    func beginReturnsOptionsAsJSON() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            holder.service = MockPasskeyService()
            try await self.configure(app, passkeyService: holder.service)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "email=alice@example.com&displayName=Alice")
            ) { res in
                #expect(res.status == .ok)

                // Must be a real JSON object, not an HTML redirect.
                let json = try #require(
                    try JSONSerialization.jsonObject(with: Data(buffer: res.body)) as? [String: Any],
                    "response body must parse as a JSON object"
                )

                // rp mirrors configuration.
                let rp = try #require(json["rp"] as? [String: Any])
                #expect(rp["id"] as? String == "example.com")
                #expect(rp["name"] as? String == "Test RP")  // from MockPasskeyService default

                // user block carries the identifier + displayName.
                let user = try #require(json["user"] as? [String: Any])
                #expect(user["name"] as? String == "alice@example.com")
                #expect(user["displayName"] as? String == "Alice")

                // challenge must be base64url (no +, /, =).
                let challenge = try #require(json["challenge"] as? String)
                #expect(!challenge.isEmpty)
                #expect(!challenge.contains("+"))
                #expect(!challenge.contains("/"))
                #expect(!challenge.contains("="))

                // user.id must also be base64url.
                let userId = try #require(user["id"] as? String)
                #expect(!userId.contains("="))
            }
        }
    }

    @Test("Service receives a user entity derived from the form identifier")
    func serviceReceivesForwardedIdentifier() async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            holder.service = MockPasskeyService()
            try await self.configure(app, passkeyService: holder.service)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "phone=%2B15551234567&displayName=Alice%20A")
            ) { res in
                #expect(res.status == .ok)

                let captured = try #require(holder.service?.calls)
                #expect(captured.count == 1)

                let entity = try #require(captured.first?.user)
                #expect(entity.name == "+15551234567")  // phone becomes user.name
                #expect(entity.displayName == "Alice A")
                #expect(entity.id.count == 32)  // SHA-256 digest of the identifier
            }
        }
    }

    @Test("Service receives the configured policy (timeout, algorithms, attestation)")
    func serviceReceivesConfiguredPolicy() async throws {
        let policy = Passage.Configuration.Passkey.Policy(
            timeout: .seconds(120),
            attestation: .direct,
            userVerification: .required,
            supportedAlgorithms: [.ES256, .RS256, .EdDSA]
        )

        let holder = Holder()
        try await withApp(configure: { app in
            holder.service = MockPasskeyService()

            let services = Passage.Services(
                store: Passage.OnlyForTest.InMemoryStore(),
                random: DefaultRandomGenerator(),
                emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
                phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
                federatedLogin: nil,
                passkey: holder.service
            )

            await app.jwt.keys.add(
                hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
                digestAlgorithm: .sha256,
                kid: JWKIdentifier(string: "test-key")
            )

            let configuration = try Passage.Configuration(
                origin: URL(string: "http://localhost:8080")!,
                routes: .init(),
                tokens: .init(
                    issuer: "test-issuer",
                    accessToken: .init(timeToLive: 3600),
                    refreshToken: .init(timeToLive: 86400)
                ),
                jwt: .init(jwks: .init(json: #"{"keys":[]}"#)),
                verification: .init(
                    email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                    phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                    useQueues: false
                ),
                restoration: .init(
                    email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                    phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                    useQueues: false
                ),
                passkey: .init(
                    policy: policy
                )
            )

            try await app.passage.configure(services: services, configuration: configuration)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "username=alice&displayName=Alice")
            ) { res in
                #expect(res.status == .ok)

                let received = try #require(holder.service?.calls.first?.policy)
                #expect(received.timeout == .seconds(120))
                #expect(received.attestation == .direct)
                #expect(received.userVerification == .required)
                #expect(received.supportedAlgorithms == [.ES256, .RS256, .EdDSA])
            }
        }
    }

    // MARK: - Identifier variants

    @Test("Email identifier flows through to user.name",
          arguments: [
            ("email=alice%40example.com&displayName=Alice", "alice@example.com"),
            ("phone=%2B15551234567&displayName=Alice", "+15551234567"),
            ("username=alice&displayName=Alice", "alice"),
          ])
    func identifierFlowsToUserName(body: String, expectedUserName: String) async throws {
        let holder = Holder()
        try await withApp(configure: { app in
            holder.service = MockPasskeyService()
            try await self.configure(app, passkeyService: holder.service)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: body)
            ) { res in
                #expect(res.status == .ok)

                let json = try #require(
                    try JSONSerialization.jsonObject(with: Data(buffer: res.body)) as? [String: Any]
                )
                let user = try #require(json["user"] as? [String: Any])
                #expect(user["name"] as? String == expectedUserName)
            }
        }
    }

    // MARK: - Validation / form errors

    @Test("POST begin returns 400 when no identifier is provided")
    func missingIdentifierReturns400() async throws {
        try await withApp(configure: { app in
            try await self.configure(app)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "displayName=Alice")
            ) { res in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("POST begin returns 400 when required displayName is missing")
    func missingDisplayNameReturns400() async throws {
        try await withApp(configure: { app in
            try await self.configure(app)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "email=alice@example.com")
            ) { res in
                #expect(res.status == .badRequest)
            }
        }
    }

    // MARK: - Service absent / service errors

    @Test("POST begin returns 404 when no PasskeyService is registered (routes not registered)")
    func serviceNotRegisteredReturns404() async throws {
        try await withApp(configure: { app in
            try await self.configure(app, passkeyService: nil)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "email=alice@example.com&displayName=Alice")
            ) { res in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("POST begin propagates service errors as 500 JSON")
    func serviceErrorBubblesUp() async throws {
        struct BoomError: AbortError {
            var status: HTTPResponseStatus { .internalServerError }
            var reason: String { "boom" }
        }

        try await withApp(configure: { app in
            let service = MockPasskeyService(error: BoomError())
            try await self.configure(app, passkeyService: service)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "email=alice@example.com&displayName=Alice")
            ) { res in
                #expect(res.status == .internalServerError)
            }
        }
    }

    // MARK: - Route registration gating

    @Test("Begin route is not registered when configuration.passkey is nil")
    func beginRouteAbsentWithoutPasskeyConfig() async throws {
        try await withApp(configure: { app in
            try await self.configure(app, includePasskeyConfig: false)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "email=alice@example.com&displayName=Alice")
            ) { res in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("Begin route honors custom registerBegin path from configuration")
    func beginRouteRespectsCustomPath() async throws {
        let customRoutes = Passage.Configuration.Passkey.Routes(
            signupBegin: .init(path: "start")
        )

        try await withApp(configure: { app in
            try await self.configure(app, passkeyRoutes: customRoutes)
        }) { app in
            // Default path should now 404…
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "email=alice@example.com&displayName=Alice")
            ) { res in
                #expect(res.status == .notFound)
            }

            // …and the override should succeed.
            try await app.testing().test(
                .POST, "/auth/passkey/start",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "email=alice@example.com&displayName=Alice")
            ) { res in
                #expect(res.status == .ok)
            }
        }
    }

    // MARK: - Dual-mode HTML fallback

    @Test("HTML form submission with passkeySignup view configured redirects to the passkey view")
    func htmlFallbackRedirectsToPasskeyView() async throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let viewsConfig = Passage.Configuration.Views(
            passkeySignup: .init(style: .minimalism, theme: theme, identifier: .email)
        )

        try await withApp(configure: { app in
            try await self.configure(app, views: viewsConfig)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "text/html"
                ],
                body: .init(string: "email=alice@example.com&displayName=Alice")
            ) { res in
                // Either 303 See Other or 302 Found depending on Vapor version.
                #expect(res.status == .seeOther || res.status == .found)

                let location = try #require(res.headers.first(name: .location))
                // This is the key bug-fix: redirect goes to the passkey view,
                // NOT to /auth/login (the old `views.login` bug).
                #expect(location.contains("/auth/passkey/signup/begin"))
                #expect(!location.hasPrefix("/auth/login"))
                #expect(location.contains("success="))
            }
        }
    }

    @Test("HTML form submission with failing service redirects to passkey view with error")
    func htmlFallbackRedirectsOnErrorToPasskeyView() async throws {
        struct BoomError: AbortError {
            var status: HTTPResponseStatus { .badRequest }
            var reason: String { "identifier rejected" }
        }

        let theme = Passage.Views.Theme(colors: .defaultLight)
        let viewsConfig = Passage.Configuration.Views(
            passkeySignup: .init(style: .minimalism, theme: theme, identifier: .email)
        )

        try await withApp(configure: { app in
            let service = MockPasskeyService(error: BoomError())
            try await self.configure(app, passkeyService: service, views: viewsConfig)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "text/html"
                ],
                body: .init(string: "email=alice@example.com&displayName=Alice")
            ) { res in
                #expect(res.status == .seeOther || res.status == .found)

                let location = try #require(res.headers.first(name: .location))
                #expect(location.contains("/auth/passkey/signup/begin"))
                #expect(!location.hasPrefix("/auth/login"))
                #expect(location.contains("error="))
            }
        }
    }

    @Test("HTML Accept without a configured passkey view still returns JSON")
    func htmlAcceptWithoutViewReturnsJSON() async throws {
        try await withApp(configure: { app in
            // No views.passkeySignup — guard falls through to JSON.
            try await self.configure(app)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/signup/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "text/html"
                ],
                body: .init(string: "email=alice@example.com&displayName=Alice")
            ) { res in
                #expect(res.status == .ok)

                // Body should be JSON, not a redirect.
                let json = try? JSONSerialization.jsonObject(with: Data(buffer: res.body)) as? [String: Any]
                #expect(json != nil)
            }
        }
    }

    // MARK: - View (GET) — begin endpoint as HTML entry point

    @Test("GET begin view returns 404 when passkeySignup view is not configured")
    func viewNotConfiguredReturns404() async throws {
        try await withApp(configure: { app in
            try await self.configure(app)
        }) { app in
            try await app.testing().test(.GET, "/auth/passkey/signup/begin") { res in
                #expect(res.status == .notFound)
            }
        }
    }

    @Test("GET begin view renders passkey-register template with identifier flags")
    func viewRendersWithIdentifierFlags() async throws {
        let viewsConfig = Passage.Configuration.Views(
            passkeySignup: .init(
                style: .minimalism,
                theme: Passage.Views.Theme(colors: .defaultLight),
                identifier: .email
            )
        )

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            app.views.use { _ in renderer }

            try await self.configure(app, views: viewsConfig)

            try await app.testing().test(.GET, "/auth/passkey/signup/begin") { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "passkey-signup-minimalism")

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.PasskeySignupViewParams>
                let params = try #require(ctx?.params)
                #expect(params.byEmail == true)
                #expect(params.byPhone == false)
                #expect(params.byUsername == false)
            }
        }
    }

    @Test("GET begin view passes signupBeginURL and signupFinishURL to the template")
    func viewForwardsURLs() async throws {
        let viewsConfig = Passage.Configuration.Views(
            passkeySignup: .init(
                style: .minimalism,
                theme: Passage.Views.Theme(colors: .defaultLight),
                identifier: .email
            )
        )

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            app.views.use { _ in renderer }

            try await self.configure(app, views: viewsConfig)

            try await app.testing().test(.GET, "/auth/passkey/signup/begin") { res in
                #expect(res.status == .ok)

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.PasskeySignupViewParams>
                let params = try #require(ctx?.params)

                // The leaf template reads these to drive its `fetch` calls.
                #expect(params.signupBeginURL == "/auth/passkey/signup/begin")
                #expect(params.signupFinishURL == "/auth/passkey/signup/finish")
            }
        }
    }

    @Test("View-side URLs track custom passkey route overrides")
    func viewURLsFollowCustomRoutes() async throws {
        let passkeyRoutes = Passage.Configuration.Passkey.Routes(
            group: ["pk"],
            signupBegin: .init(path: "start"),
            signupFinish: .init(path: "done")
        )

        let viewsConfig = Passage.Configuration.Views(
            passkeySignup: .init(
                style: .minimalism,
                theme: Passage.Views.Theme(colors: .defaultLight),
                identifier: .email
            )
        )

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            app.views.use { _ in renderer }

            try await self.configure(app, views: viewsConfig, passkeyRoutes: passkeyRoutes)

            try await app.testing().test(.GET, "/auth/pk/start") { res in
                #expect(res.status == .ok)

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.PasskeySignupViewParams>
                let params = try #require(ctx?.params)

                #expect(params.signupBeginURL == "/auth/pk/start")
                #expect(params.signupFinishURL == "/auth/pk/done")
            }
        }
    }
}

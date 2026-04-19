import Testing
import Vapor
import VaporTesting
import JWTKit
@testable import Passage
@testable import PassageOnlyForTest

/// Tests the private `buildRedirectURL(base:code:)` helper inside
/// `Passage.FederatedLogin` by driving the full `login(identity:)` path and
/// asserting the resulting redirect location header.
///
/// There are two branches:
///  • Base URL without an existing query string → appends `?code=<value>`
///  • Base URL that already contains `?` → appends `&code=<value>`
@Suite("FederatedLogin buildRedirectURL Tests", .tags(.unit, .federatedLogin))
struct FederatedLoginBuildRedirectURLTests {

    @Sendable private func configureApp(_ app: Application, redirectLocation: String) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: nil,
            phoneDelivery: nil,
            federatedLogin: nil
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
            federatedLogin: .init(
                providers: [],
                accountLinking: .init(resolution: .disabled),
                redirectLocation: redirectLocation
            )
        )

        try await app.passage.configure(services: services, configuration: configuration)
    }

    // MARK: - Clean base URL (no existing query string)

    @Test("buildRedirectURL appends ?code= when base has no query string")
    func appendsQueryParamWhenBaseIsClean() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configureApp(app, redirectLocation: "/dashboard")

        let identity = FederatedIdentity(
            identifier: .federated(.google, userId: "test-user"),
            provider: .google,
            verifiedEmails: [],
            verifiedPhoneNumbers: [],
            displayName: nil,
            profilePictureURL: nil
        )

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let response = try await request.federated.login(identity: identity)

        let location = response.headers.first(name: .location) ?? ""
        #expect(location.contains("/dashboard?code="))
        #expect(!location.contains("&code="))
    }

    // MARK: - Base URL with existing query string

    @Test("buildRedirectURL appends &code= when base already contains a query string")
    func appendsAmpersandParamWhenBaseHasQuery() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configureApp(app, redirectLocation: "/dashboard?from=oauth")

        let identity = FederatedIdentity(
            identifier: .federated(.google, userId: "test-user-2"),
            provider: .google,
            verifiedEmails: [],
            verifiedPhoneNumbers: [],
            displayName: nil,
            profilePictureURL: nil
        )

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let response = try await request.federated.login(identity: identity)

        let location = response.headers.first(name: .location) ?? ""
        #expect(location.contains("from=oauth"))
        #expect(location.contains("&code="))
        #expect(!location.contains("?code="))
    }
}

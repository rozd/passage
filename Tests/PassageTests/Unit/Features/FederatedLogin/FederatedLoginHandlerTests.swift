import Testing
import Vapor
import JWTKit
@testable import Passage
@testable import PassageOnlyForTest

// MARK: - Mock FederatedLoginService

private final class CapturingFederatedLoginService: Passage.FederatedLoginService, @unchecked Sendable {
    var registerCallCount = 0

    func register(
        router: any RoutesBuilder,
        origin: URL,
        group: [PathComponent],
        config: Passage.Configuration.FederatedLogin,
        onSignIn: @escaping @Sendable (
            _ request: Request,
            _ identity: FederatedIdentity
        ) async throws -> some AsyncResponseEncodable
    ) throws {
        registerCallCount += 1
    }
}

// MARK: - Tests

@Suite("FederatedLogin Handler Tests", .tags(.unit, .federatedLogin))
struct FederatedLoginHandlerTests {

    @Sendable private func makeConfiguration() throws -> Passage.Configuration {
        try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: #"{"keys":[]}"#))
        )
    }

    // MARK: - No Service

    @Test("register() returns without error when no federated service is configured")
    func registerDoesNothingWithoutService() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

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
        let configuration = try makeConfiguration()
        try await app.passage.configure(services: services, configuration: configuration)

        let handler = Passage.FederatedLoginHandler(app: app, configuration: configuration)
        try handler.register()
    }

    // MARK: - With Service

    @Test("configure() calls service.register() when a federated service is provided")
    func configureCallsServiceRegister() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        let mockService = CapturingFederatedLoginService()
        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: nil,
            phoneDelivery: nil,
            federatedLogin: mockService
        )
        let configuration = try makeConfiguration()
        try await app.passage.configure(services: services, configuration: configuration)

        // configure() internally creates a FederatedLoginHandler and calls register(),
        // which must forward to service.register() exactly once.
        #expect(mockService.registerCallCount == 1)
    }

    @Test("register() forwards origin from configuration to service")
    func registerForwardsOrigin() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        final class RecordingService: Passage.FederatedLoginService, @unchecked Sendable {
            var capturedOrigin: URL?
            func register(
                router: any RoutesBuilder,
                origin: URL,
                group: [PathComponent],
                config: Passage.Configuration.FederatedLogin,
                onSignIn: @escaping @Sendable (Request, FederatedIdentity) async throws -> some AsyncResponseEncodable
            ) throws {
                capturedOrigin = origin
            }
        }

        let recordingService = RecordingService()
        let services = Passage.Services(
            store: Passage.OnlyForTest.InMemoryStore(),
            random: DefaultRandomGenerator(),
            emailDelivery: nil,
            phoneDelivery: nil,
            federatedLogin: recordingService
        )
        let configuration = try Passage.Configuration(
            origin: URL(string: "https://myapp.example.com")!,
            routes: .init(),
            tokens: .init(
                issuer: "issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: #"{"keys":[]}"#))
        )
        try await app.passage.configure(services: services, configuration: configuration)

        let handler = Passage.FederatedLoginHandler(app: app, configuration: configuration)
        try handler.register()

        #expect(recordingService.capturedOrigin?.host == "myapp.example.com")
    }
}

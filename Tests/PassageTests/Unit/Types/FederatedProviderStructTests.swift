import Testing
@testable import Passage

@Suite
struct `FederatedProvider Struct Tests` {

    // MARK: - Provider Nested Type Tests

    @Test
    func `Provider is nested within FederatedLogin`() {
        let typeName = String(reflecting: FederatedProvider.self)
        #expect(typeName.contains("FederatedProvider"))
    }

    @Test
    func `Provider Name is nested within Provider`() {
        let typeName = String(reflecting: FederatedProvider.Name.self)
        #expect(typeName.contains("FederatedProvider.Name"))
    }

    @Test
    func `Provider Credentials is nested within Provider`() {
        let typeName = String(reflecting: FederatedProvider.Credentials.self)
        #expect(typeName.contains("FederatedProvider.Credentials"))
    }

    // MARK: - Type Hierarchy Tests

    @Test
    func `FederatedLogin namespace contains Provider`() {
        // Create a provider to verify it's accessible through FederatedLogin
        let provider = FederatedProvider.google()
        #expect(provider.name.description == "google")
    }

    // MARK: - Integration Tests

    @Test
    func `Can create multiple providers with different configurations`() {
        let providers: [FederatedProvider] = [
            .google(scope: ["email"]),
            .github(scope: ["user"]),
            .custom(name: "custom", scope: ["openid"])
        ]

        #expect(providers.count == 3)
        #expect(providers[0].name.description == "google")
        #expect(providers[1].name.description == "github")
        #expect(providers[2].name.description == "custom")
    }

    @Test
    func `Provider with different credential types`() {
        let conventional = FederatedProvider.google()
        let withClient = FederatedProvider.google(
            credentials: .client(id: "id", secret: "secret")
        )

        if case .conventional = conventional.credentials {
            // Success
        } else {
            Issue.record("Expected conventional credentials")
        }

        if case .client = withClient.credentials {
            // Success
        } else {
            Issue.record("Expected client credentials")
        }
    }

    // MARK: - Name Equality Tests

    @Test
    func `Provider names with same rawValue are equal`() {
        let name1 = FederatedProvider.Name("test")
        let name2 = FederatedProvider.Name("test")

        #expect(name1 == name2)
    }

    @Test
    func `Provider names with different rawValue are not equal`() {
        let name1 = FederatedProvider.Name("test1")
        let name2 = FederatedProvider.Name("test2")

        #expect(name1 != name2)
    }

    @Test
    func `Static provider names are equal to constructed ones`() {
        let staticGoogle = FederatedProvider.Name.google
        let constructedGoogle = FederatedProvider.Name("google")

        #expect(staticGoogle == constructedGoogle)
    }

    // MARK: - Scope Tests

    @Test
    func `Provider with empty scope`() {
        let provider = FederatedProvider.google()
        #expect(provider.scope.isEmpty)
    }

    @Test
    func `Provider with single scope`() {
        let provider = FederatedProvider.google(scope: ["email"])
        #expect(provider.scope == ["email"])
    }

    @Test
    func `Provider with multiple scopes`() {
        let provider = FederatedProvider.google(scope: ["email", "profile", "openid"])
        #expect(provider.scope.count == 3)
        #expect(provider.scope.contains("email"))
        #expect(provider.scope.contains("profile"))
        #expect(provider.scope.contains("openid"))
    }

    // MARK: - Credentials Pattern Matching Tests

    @Test
    func `Can pattern match conventional credentials`() {
        let provider = FederatedProvider.google()

        switch provider.credentials {
        case .conventional:
            // Success
            break
        case .client:
            Issue.record("Expected conventional credentials")
        }
    }

    @Test
    func `Can pattern match client credentials`() {
        let provider = FederatedProvider.google(
            credentials: .client(id: "test-id", secret: "test-secret")
        )

        switch provider.credentials {
        case .conventional:
            Issue.record("Expected client credentials")
        case .client(let id, let secret):
            #expect(id == "test-id")
            #expect(secret == "test-secret")
        }
    }

}

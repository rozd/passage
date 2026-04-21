import Testing
import Vapor
@testable import Passage

@Suite
struct `Federated Provider Tests` {

    // MARK: - Provider Name Tests

    @Test
    func `Provider Name initialization with rawValue`() {
        let name = FederatedProvider.Name("custom")
        #expect(name.description == "custom")
    }

    @Test
    func `Provider Name google static member`() {
        let google = FederatedProvider.Name.google
        #expect(google.description == "google")
    }

    @Test
    func `Provider Name github static member`() {
        let github = FederatedProvider.Name.github
        #expect(github.description == "github")
    }

    @Test
    func `Provider Name named factory method`() {
        let name = FederatedProvider.Name.named("custom-provider")
        #expect(name.description == "custom-provider")
    }

    @Test
    func `Provider Name conforms to Codable`() throws {
        let name = FederatedProvider.Name("test")

        let encoder = JSONEncoder()
        let data = try encoder.encode(name)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FederatedProvider.Name.self, from: data)

        #expect(decoded.description == name.description)
    }

    @Test
    func `Provider Name conforms to Hashable`() {
        let name1 = FederatedProvider.Name("test")
        let name2 = FederatedProvider.Name("test")
        let name3 = FederatedProvider.Name("different")

        #expect(name1 == name2)
        #expect(name1 != name3)

        var set = Set<FederatedProvider.Name>()
        set.insert(name1)
        set.insert(name2)

        #expect(set.count == 1)
    }

    @Test
    func `Provider Name conforms to Sendable`() {
        let _: any Sendable.Type = FederatedProvider.Name.self
    }

    // MARK: - Provider Credentials Tests

    @Test
    func `Provider Credentials conventional case`() {
        let credentials = FederatedProvider.Credentials.conventional

        if case .conventional = credentials {
            // Success
        } else {
            Issue.record("Expected conventional credentials")
        }
    }

    @Test
    func `Provider Credentials client case`() {
        let credentials = FederatedProvider.Credentials.client(
            id: "client-id",
            secret: "client-secret"
        )

        if case .client(let id, let secret) = credentials {
            #expect(id == "client-id")
            #expect(secret == "client-secret")
        } else {
            Issue.record("Expected client credentials")
        }
    }

    @Test
    func `Provider Credentials conforms to Sendable`() {
        let _: any Sendable.Type = FederatedProvider.Credentials.self
    }

    // MARK: - Provider Initialization Tests

    @Test
    func `Provider initialization with all parameters`() {
        let name = FederatedProvider.Name("google")
        let credentials = FederatedProvider.Credentials.client(id: "id", secret: "secret")
        let scope = ["email", "profile"]

        let provider = FederatedProvider(
            name: name,
            credentials: credentials,
            scope: scope,
        )

        #expect(provider.name.description == "google")
        #expect(provider.scope == ["email", "profile"])
    }

    @Test
    func `Provider initialization with conventional credentials`() {
        let name = FederatedProvider.Name.google
        let provider = FederatedProvider(name: name)

        if case .conventional = provider.credentials {
            // Success
        } else {
            Issue.record("Expected conventional credentials by default")
        }
    }

    @Test
    func `Provider initialization with empty scope`() {
        let name = FederatedProvider.Name.google
        let provider = FederatedProvider(name: name)

        #expect(provider.scope.isEmpty)
    }

    // MARK: - Provider Convenience Initializers Tests

    @Test
    func `Provider google() convenience initializer`() {
        let provider = FederatedProvider.google()

        #expect(provider.name.description == "google")
        #expect(provider.scope.isEmpty)
    }

    @Test
    func `Provider google() with credentials`() {
        let credentials = FederatedProvider.Credentials.client(id: "google-id", secret: "google-secret")
        let provider = FederatedProvider.google(credentials: credentials)

        if case .client(let id, let secret) = provider.credentials {
            #expect(id == "google-id")
            #expect(secret == "google-secret")
        } else {
            Issue.record("Expected client credentials")
        }
    }

    @Test
    func `Provider google() with scope`() {
        let provider = FederatedProvider.google(scope: ["email", "profile"])

        #expect(provider.scope == ["email", "profile"])
    }

    @Test
    func `Provider github() convenience initializer`() {
        let provider = FederatedProvider.github()

        #expect(provider.name.description == "github")
        #expect(provider.scope.isEmpty)
    }

    @Test
    func `Provider github() with credentials`() {
        let credentials = FederatedProvider.Credentials.client(id: "github-id", secret: "github-secret")
        let provider = FederatedProvider.github(credentials: credentials)

        if case .client(let id, let secret) = provider.credentials {
            #expect(id == "github-id")
            #expect(secret == "github-secret")
        } else {
            Issue.record("Expected client credentials")
        }
    }

    @Test
    func `Provider github() with scope`() {
        let provider = FederatedProvider.github(scope: ["user:email", "read:user"])

        #expect(provider.scope == ["user:email", "read:user"])
    }

    @Test
    func `Provider custom() convenience initializer`() {
        let provider = FederatedProvider.custom(name: "custom-oauth")

        #expect(provider.name.description == "custom-oauth")
    }

    @Test
    func `Provider custom() with all parameters`() {
        let credentials = FederatedProvider.Credentials.client(id: "custom-id", secret: "custom-secret")

        let provider = FederatedProvider.custom(
            name: "custom-provider",
            credentials: credentials,
            scope: ["openid", "profile"],
        )

        #expect(provider.name.description == "custom-provider")
        #expect(provider.scope == ["openid", "profile"])
    }

    // MARK: - Multiple Providers Tests

    @Test
    func `Multiple providers can coexist`() {
        let google = FederatedProvider.google(scope: ["email"])
        let github = FederatedProvider.github(scope: ["user"])

        #expect(google.name.description == "google")
        #expect(github.name.description == "github")
        #expect(google.scope != github.scope)
    }

    @Test
    func `Provider instances are independent`() {
        let provider1 = FederatedProvider.google(scope: ["email"])
        let provider2 = FederatedProvider.google(scope: ["profile"])

        #expect(provider1.scope != provider2.scope)
    }

    // MARK: - Path Component Conversion Tests

    @Test
    func `Provider with multi-segment name`() {
        let name = FederatedProvider.Name("oauth/provider")
        let provider = FederatedProvider(name: name)

        // The rawValue is stored as-is
        #expect(provider.name.description == "oauth/provider")
    }

    // MARK: - Provider Sendable Conformance Tests

    @Test
    func `Provider conforms to Sendable`() {
        let _: any Sendable.Type = FederatedProvider.self
    }
}

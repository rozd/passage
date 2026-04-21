import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite("Linking Struct Tests", .tags(.unit, .federatedLogin))
struct LinkingStructTests {

    // MARK: - Configuration Helper

    @Sendable private func configure(_ app: Application) async throws {
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
            jwt: .init(jwks: .init(json: "{\"keys\":[]}")),
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
            federatedLogin: .init(
                providers: [],
                accountLinking: .init(resolution: .automatic(matchBy: [.email], onAmbiguity: .requestManualSelection)),
                redirectLocation: "/dashboard"
            )
        )

        try await app.passage.configure(services: services, configuration: configuration)
    }

    // MARK: - Initialization Tests

    @Test("Passage.Linking is accessible from Request")
    func linkingAccessibleFromRequest() async throws {
        try await withApp(configure: configure) { app in
            let request = Request(application: app, on: app.eventLoopGroup.any())
            let linking = request.linking

            // Linking should be accessible
            #expect(linking is Passage.Linking)
        }
    }

    @Test("Passage.Linking provides automatic accessor")
    func linkingProvidesAutomaticAccessor() async throws {
        try await withApp(configure: configure) { app in
            let request = Request(application: app, on: app.eventLoopGroup.any())
            let automatic = request.linking.automatic

            #expect(automatic is Passage.Linking.AutomaticLinking)
        }
    }

    @Test("Passage.Linking provides manual accessor")
    func linkingProvidesManualAccessor() async throws {
        try await withApp(configure: configure) { app in
            let request = Request(application: app, on: app.eventLoopGroup.any())
            let manual = request.linking.manual

            #expect(manual is Passage.Linking.ManualLinking)
        }
    }

    // MARK: - Service Accessor Tests

    @Test("Passage.Linking provides config accessor")
    func linkingProvidesConfigAccessor() async throws {
        try await withApp(configure: configure) { app in
            let request = Request(application: app, on: app.eventLoopGroup.any())
            let config = request.linking.config

            // Should return AccountLinking configuration
            #expect(config.stateExpiration == 600) // Default
        }
    }

    @Test("Passage.Linking provides store accessor")
    func linkingProvidesStoreAccessor() async throws {
        try await withApp(configure: configure) { app in
            let request = Request(application: app, on: app.eventLoopGroup.any())
            let store = request.linking.store

            // Should be InMemoryStore
            #expect(store is Passage.OnlyForTest.InMemoryStore)
        }
    }

    @Test("Passage.Linking provides random accessor")
    func linkingProvidesRandomAccessor() async throws {
        try await withApp(configure: configure) { app in
            let request = Request(application: app, on: app.eventLoopGroup.any())
            let random = request.linking.random

            // Should be DefaultRandomGenerator
            #expect(random is DefaultRandomGenerator)
        }
    }

    // MARK: - Link Helper Method Tests

    @Test("Link method throws when identifier already linked to different user")
    func linkThrowsWhenIdentifierLinkedToDifferentUser() async throws {
        try await withApp(configure: configure) { app in
            let store = app.passage.storage.services.store

            // Create two users
            let user1 = try await store.users.create(
                identifier: .email("user1@example.com"),
                with: nil
            )
            let user2 = try await store.users.create(
                identifier: .email("user2@example.com"),
                with: nil
            )

            // Add federated identifier to user1
            let federatedId = Identifier.federated(.google, userId: "shared-id")
            try await store.users.addIdentifier(federatedId, to: user1, with: nil)

            // Try to link same federated identifier to user2 - should fail
            let request = Request(application: app, on: app.eventLoopGroup.any())

            await #expect(throws: (any Error).self) {
                try await request.linking.link(
                    federatedIdentifier: federatedId,
                    to: user2
                )
            }
        }
    }

    @Test("Link method succeeds when identifier already linked to same user")
    func linkSucceedsWhenIdentifierLinkedToSameUser() async throws {
        try await withApp(configure: configure) { app in
            let store = app.passage.storage.services.store

            // Create user
            let user = try await store.users.create(
                identifier: .email("existing@example.com"),
                with: nil
            )

            // Add federated identifier
            let federatedId = Identifier.federated(.google, userId: "user-id")
            try await store.users.addIdentifier(federatedId, to: user, with: nil)

            // Link same identifier to same user - should succeed (no-op)
            let request = Request(application: app, on: app.eventLoopGroup.any())

            // Should not throw
            try await request.linking.link(
                federatedIdentifier: federatedId,
                to: user
            )
        }
    }

    @Test("Link method adds new identifier when not existing")
    func linkAddsNewIdentifierWhenNotExisting() async throws {
        try await withApp(configure: configure) { app in
            let store = app.passage.storage.services.store

            // Create user
            let user = try await store.users.create(
                identifier: .email("addidentifier@example.com"),
                with: nil
            )

            let federatedId = Identifier.federated(.github, userId: "new-github-id")

            // Before linking
            let beforeLink = try await store.users.find(byIdentifier: federatedId)
            #expect(beforeLink == nil)

            // Link the identifier
            let request = Request(application: app, on: app.eventLoopGroup.any())
            try await request.linking.link(
                federatedIdentifier: federatedId,
                to: user
            )

            // After linking
            let afterLink = try await store.users.find(byIdentifier: federatedId)
            #expect(afterLink != nil)
            #expect(afterLink?.id?.description == user.id?.description)
        }
    }

    // MARK: - Sendable Tests

    @Test("Passage.Linking conforms to Sendable")
    func linkingConformsToSendable() async throws {
        try await withApp(configure: configure) { app in
            let request = Request(application: app, on: app.eventLoopGroup.any())
            let linking: any Sendable = request.linking

            #expect(linking is Passage.Linking)
        }
    }

    @Test("Passage.Linking.AutomaticLinking conforms to Sendable")
    func automaticLinkingConformsToSendable() async throws {
        try await withApp(configure: configure) { app in
            let request = Request(application: app, on: app.eventLoopGroup.any())
            let automatic: any Sendable = request.linking.automatic

            #expect(automatic is Passage.Linking.AutomaticLinking)
        }
    }

    @Test("Passage.Linking.ManualLinking conforms to Sendable")
    func manualLinkingConformsToSendable() async throws {
        try await withApp(configure: configure) { app in
            let request = Request(application: app, on: app.eventLoopGroup.any())
            let manual: any Sendable = request.linking.manual

            #expect(manual is Passage.Linking.ManualLinking)
        }
    }
}

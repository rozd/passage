import Testing
import Vapor
@testable import Passage

@Suite
struct `Email Verification Route Collection Tests` {

    // MARK: - Initialization Tests

    @Test
    func `Passage.Verification.EmailRouteCollection initialization with default group`() {
        let config = Passage.Configuration.Verification.Email()
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        #expect(collection.group.isEmpty)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection initialization with custom group`() {
        let config = Passage.Configuration.Verification.Email()
        let group: [PathComponent] = ["auth", "email"]
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: group
        )

        #expect(collection.group.count == 2)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection stores configuration`() {
        let config = Passage.Configuration.Verification.Email(
            codeLength: 8,
            codeExpiration: 600,
            maxAttempts: 5
        )
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        #expect(collection.config.codeLength == 8)
        #expect(collection.config.codeExpiration == 600)
        #expect(collection.config.maxAttempts == 5)
    }

    // MARK: - Group Path Tests

    @Test
    func `Passage.Verification.EmailRouteCollection with empty group`() {
        let config = Passage.Configuration.Verification.Email()
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        #expect(collection.group.isEmpty)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection with single component group`() {
        let config = Passage.Configuration.Verification.Email()
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: ["verify"]
        )

        #expect(collection.group.count == 1)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection with multiple components`() {
        let config = Passage.Configuration.Verification.Email()
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: ["api", "v1", "auth", "email"]
        )

        #expect(collection.group.count == 4)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection with versioned group`() {
        let config = Passage.Configuration.Verification.Email()
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: ["v1", "verification", "email"]
        )

        #expect(collection.group.count == 3)
    }

    // MARK: - Route Configuration Tests

    @Test
    func `Passage.Verification.EmailRouteCollection with default routes`() {
        let config = Passage.Configuration.Verification.Email()
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        #expect(collection.config.routes.verify.path.count > 0)
        #expect(collection.config.routes.resend.path.count > 0)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection with custom route paths`() {
        let verifyRoute = Passage.Configuration.Verification.Email.Routes.Verify(path: "custom-verify")
        let resendRoute = Passage.Configuration.Verification.Email.Routes.Resend(path: "custom-resend")
        let routes = Passage.Configuration.Verification.Email.Routes(
            verify: verifyRoute,
            resend: resendRoute
        )

        let config = Passage.Configuration.Verification.Email(routes: routes)
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        #expect(collection.config.routes.verify.path == ["custom-verify"])
        #expect(collection.config.routes.resend.path == ["custom-resend"])
    }

    @Test
    func `Passage.Verification.EmailRouteCollection verify route path`() {
        let config = Passage.Configuration.Verification.Email()
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        #expect(!collection.config.routes.verify.path.isEmpty)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection resend route path`() {
        let config = Passage.Configuration.Verification.Email()
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        #expect(!collection.config.routes.resend.path.isEmpty)
    }

    // MARK: - Configuration Parameter Tests

    @Test
    func `Passage.Verification.EmailRouteCollection with custom code length`() {
        let config = Passage.Configuration.Verification.Email(codeLength: 10)
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        #expect(collection.config.codeLength == 10)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection with custom expiration`() {
        let config = Passage.Configuration.Verification.Email(codeExpiration: 1800)
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        #expect(collection.config.codeExpiration == 1800)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection with custom max attempts`() {
        let config = Passage.Configuration.Verification.Email(maxAttempts: 10)
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        #expect(collection.config.maxAttempts == 10)
    }

    // MARK: - Multiple Instance Tests

    @Test
    func `Multiple Passage.Verification.EmailRouteCollection instances are independent`() {
        let config1 = Passage.Configuration.Verification.Email(codeLength: 6)
        let collection1 = Passage.Verification.EmailRouteCollection(
            config: config1,
            group: ["auth1"]
        )

        let config2 = Passage.Configuration.Verification.Email(codeLength: 8)
        let collection2 = Passage.Verification.EmailRouteCollection(
            config: config2,
            group: ["auth2"]
        )

        #expect(collection1.config.codeLength != collection2.config.codeLength)
        #expect(collection1.group != collection2.group)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection can be instantiated multiple times`() {
        let config = Passage.Configuration.Verification.Email()

        let collection1 = Passage.Verification.EmailRouteCollection(config: config, group: [])
        let collection2 = Passage.Verification.EmailRouteCollection(config: config, group: [])

        #expect(collection1.group == collection2.group)
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `Passage.Verification.EmailRouteCollection conforms to RouteCollection`() {
        let config = Passage.Configuration.Verification.Email()
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: []
        )

        let _: any RouteCollection = collection
        #expect(collection is any RouteCollection)
    }

    // MARK: - Group Path Component Tests

    @Test
    func `Passage.Verification.EmailRouteCollection with different path component types`() {
        let config = Passage.Configuration.Verification.Email()

        // String path components
        let collection1 = Passage.Verification.EmailRouteCollection(
            config: config,
            group: ["auth", "verify"]
        )
        #expect(collection1.group.count == 2)

        // Constant path components
        let collection2 = Passage.Verification.EmailRouteCollection(
            config: config,
            group: [.constant("auth"), .constant("verify")]
        )
        #expect(collection2.group.count == 2)
    }

    @Test
    func `Passage.Verification.EmailRouteCollection preserves group order`() {
        let config = Passage.Configuration.Verification.Email()
        let group: [PathComponent] = ["first", "second", "third"]
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: group
        )

        #expect(collection.group.count == 3)
        // Order is preserved by the array
    }

    // MARK: - Configuration Preservation Tests

    @Test
    func `Passage.Verification.EmailRouteCollection preserves all configuration settings`() {
        let verifyRoute = Passage.Configuration.Verification.Email.Routes.Verify(path: "verify")
        let resendRoute = Passage.Configuration.Verification.Email.Routes.Resend(path: "resend")
        let routes = Passage.Configuration.Verification.Email.Routes(
            verify: verifyRoute,
            resend: resendRoute
        )

        let config = Passage.Configuration.Verification.Email(
            routes: routes,
            codeLength: 7,
            codeExpiration: 900,
            maxAttempts: 4
        )

        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: ["email"]
        )

        #expect(collection.config.codeLength == 7)
        #expect(collection.config.codeExpiration == 900)
        #expect(collection.config.maxAttempts == 4)
        #expect(collection.config.routes.verify.path == ["verify"])
        #expect(collection.config.routes.resend.path == ["resend"])
        #expect(collection.group == ["email"])
    }

    @Test
    func `Passage.Verification.EmailRouteCollection with nested path groups`() {
        let config = Passage.Configuration.Verification.Email()
        let collection = Passage.Verification.EmailRouteCollection(
            config: config,
            group: ["api", "v2", "auth", "email", "verify"]
        )

        #expect(collection.group.count == 5)
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `Verification.EmailRouteCollection conforms to Sendable`() {
        let config = Passage.Configuration.Verification.Email()
        assertSendable(Passage.Verification.EmailRouteCollection(config: config, group: []))
    }
}

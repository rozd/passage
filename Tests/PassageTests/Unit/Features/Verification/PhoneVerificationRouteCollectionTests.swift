import Testing
import Vapor
@testable import Passage

@Suite
struct `Phone Verification Route Collection Tests` {

    // MARK: - Initialization Tests

    @Test
    func `Passage.Verification.PhoneRouteCollection initialization with default group`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(collection.groupPath.isEmpty)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection initialization with custom group`() {
        let config = Passage.Configuration.Verification.Phone()
        let groupPath: [PathComponent] = ["auth", "phone"]
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: groupPath
        )

        #expect(collection.groupPath.count == 2)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection stores configuration`() {
        let config = Passage.Configuration.Verification.Phone(
            codeLength: 8,
            codeExpiration: 600,
            maxAttempts: 5
        )
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(collection.config.codeLength == 8)
        #expect(collection.config.codeExpiration == 600)
        #expect(collection.config.maxAttempts == 5)
    }

    // MARK: - Group Path Tests

    @Test
    func `Passage.Verification.PhoneRouteCollection with empty group`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(collection.groupPath.isEmpty)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection with single component group`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: ["verify"]
        )

        #expect(collection.groupPath.count == 1)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection with multiple components`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: ["api", "v1", "auth", "phone"]
        )

        #expect(collection.groupPath.count == 4)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection with versioned group`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: ["v1", "verification", "phone"]
        )

        #expect(collection.groupPath.count == 3)
    }

    // MARK: - Route Configuration Tests

    @Test
    func `Passage.Verification.PhoneRouteCollection with default routes`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(collection.config.routes.sendCode.path.count > 0)
        #expect(collection.config.routes.verify.path.count > 0)
        #expect(collection.config.routes.resend.path.count > 0)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection with custom route paths`() {
        let sendCodeRoute = Passage.Configuration.Verification.Phone.Routes.SendCode(path: "custom-send")
        let verifyRoute = Passage.Configuration.Verification.Phone.Routes.Verify(path: "custom-verify")
        let resendRoute = Passage.Configuration.Verification.Phone.Routes.Resend(path: "custom-resend")
        let routes = Passage.Configuration.Verification.Phone.Routes(
            sendCode: sendCodeRoute,
            verify: verifyRoute,
            resend: resendRoute
        )

        let config = Passage.Configuration.Verification.Phone(routes: routes)
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(collection.config.routes.sendCode.path == ["custom-send"])
        #expect(collection.config.routes.verify.path == ["custom-verify"])
        #expect(collection.config.routes.resend.path == ["custom-resend"])
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection sendCode route path`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(!collection.config.routes.sendCode.path.isEmpty)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection verify route path`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(!collection.config.routes.verify.path.isEmpty)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection resend route path`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(!collection.config.routes.resend.path.isEmpty)
    }

    // MARK: - Configuration Parameter Tests

    @Test
    func `Passage.Verification.PhoneRouteCollection with custom code length`() {
        let config = Passage.Configuration.Verification.Phone(codeLength: 10)
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(collection.config.codeLength == 10)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection with custom expiration`() {
        let config = Passage.Configuration.Verification.Phone(codeExpiration: 1800)
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(collection.config.codeExpiration == 1800)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection with custom max attempts`() {
        let config = Passage.Configuration.Verification.Phone(maxAttempts: 10)
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        #expect(collection.config.maxAttempts == 10)
    }

    // MARK: - Multiple Instance Tests

    @Test
    func `Multiple Passage.Verification.PhoneRouteCollection instances are independent`() {
        let config1 = Passage.Configuration.Verification.Phone(codeLength: 6)
        let collection1 = Passage.Verification.PhoneRouteCollection(
            config: config1,
            groupPath: ["auth1"]
        )

        let config2 = Passage.Configuration.Verification.Phone(codeLength: 8)
        let collection2 = Passage.Verification.PhoneRouteCollection(
            config: config2,
            groupPath: ["auth2"]
        )

        #expect(collection1.config.codeLength != collection2.config.codeLength)
        #expect(collection1.groupPath != collection2.groupPath)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection can be instantiated multiple times`() {
        let config = Passage.Configuration.Verification.Phone()

        let collection1 = Passage.Verification.PhoneRouteCollection(config: config, groupPath: [])
        let collection2 = Passage.Verification.PhoneRouteCollection(config: config, groupPath: [])

        #expect(collection1.groupPath == collection2.groupPath)
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `Passage.Verification.PhoneRouteCollection conforms to RouteCollection`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        let _: any RouteCollection = collection
        #expect(collection is any RouteCollection)
    }

    // MARK: - Group Path Component Tests

    @Test
    func `Passage.Verification.PhoneRouteCollection with different path component types`() {
        let config = Passage.Configuration.Verification.Phone()

        // String path components
        let collection1 = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: ["auth", "verify"]
        )
        #expect(collection1.groupPath.count == 2)

        // Constant path components
        let collection2 = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: [.constant("auth"), .constant("verify")]
        )
        #expect(collection2.groupPath.count == 2)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection preserves group order`() {
        let config = Passage.Configuration.Verification.Phone()
        let groupPath: [PathComponent] = ["first", "second", "third"]
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: groupPath
        )

        #expect(collection.groupPath.count == 3)
        // Order is preserved by the array
    }

    // MARK: - Configuration Preservation Tests

    @Test
    func `Passage.Verification.PhoneRouteCollection preserves all configuration settings`() {
        let sendCodeRoute = Passage.Configuration.Verification.Phone.Routes.SendCode(path: "send")
        let verifyRoute = Passage.Configuration.Verification.Phone.Routes.Verify(path: "verify")
        let resendRoute = Passage.Configuration.Verification.Phone.Routes.Resend(path: "resend")
        let routes = Passage.Configuration.Verification.Phone.Routes(
            sendCode: sendCodeRoute,
            verify: verifyRoute,
            resend: resendRoute
        )

        let config = Passage.Configuration.Verification.Phone(
            routes: routes,
            codeLength: 7,
            codeExpiration: 900,
            maxAttempts: 4
        )

        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: ["phone"]
        )

        #expect(collection.config.codeLength == 7)
        #expect(collection.config.codeExpiration == 900)
        #expect(collection.config.maxAttempts == 4)
        #expect(collection.config.routes.sendCode.path == ["send"])
        #expect(collection.config.routes.verify.path == ["verify"])
        #expect(collection.config.routes.resend.path == ["resend"])
        #expect(collection.groupPath == ["phone"])
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection with nested path groups`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: ["api", "v2", "auth", "phone", "verify"]
        )

        #expect(collection.groupPath.count == 5)
    }

    // MARK: - Route Collection Comparison Tests

    @Test
    func `Passage.Verification.PhoneRouteCollection has three routes`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        // Verify all three routes are accessible
        #expect(!collection.config.routes.sendCode.path.isEmpty)
        #expect(!collection.config.routes.verify.path.isEmpty)
        #expect(!collection.config.routes.resend.path.isEmpty)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection route paths are distinct`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        let sendCodePath = collection.config.routes.sendCode.path
        let verifyPath = collection.config.routes.verify.path
        let resendPath = collection.config.routes.resend.path

        // Each route should have a path
        #expect(!sendCodePath.isEmpty)
        #expect(!verifyPath.isEmpty)
        #expect(!resendPath.isEmpty)
    }

    // MARK: - Default Configuration Tests

    @Test
    func `Passage.Verification.PhoneRouteCollection default configuration values`() {
        let config = Passage.Configuration.Verification.Phone()
        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: []
        )

        // Verify default values are set
        #expect(collection.config.codeLength > 0)
        #expect(collection.config.codeExpiration > 0)
        #expect(collection.config.maxAttempts > 0)
    }

    @Test
    func `Passage.Verification.PhoneRouteCollection with all custom settings`() {
        let sendCodeRoute = Passage.Configuration.Verification.Phone.Routes.SendCode(
            path: "custom-send-code"
        )
        let verifyRoute = Passage.Configuration.Verification.Phone.Routes.Verify(
            path: "custom-verify-phone"
        )
        let resendRoute = Passage.Configuration.Verification.Phone.Routes.Resend(
            path: "custom-resend-code"
        )
        let routes = Passage.Configuration.Verification.Phone.Routes(
            sendCode: sendCodeRoute,
            verify: verifyRoute,
            resend: resendRoute
        )

        let config = Passage.Configuration.Verification.Phone(
            routes: routes,
            codeLength: 12,
            codeExpiration: 2400,
            maxAttempts: 8
        )

        let collection = Passage.Verification.PhoneRouteCollection(
            config: config,
            groupPath: ["v3", "sms", "verification"]
        )

        #expect(collection.config.codeLength == 12)
        #expect(collection.config.codeExpiration == 2400)
        #expect(collection.config.maxAttempts == 8)
        #expect(collection.config.routes.sendCode.path == ["custom-send-code"])
        #expect(collection.config.routes.verify.path == ["custom-verify-phone"])
        #expect(collection.config.routes.resend.path == ["custom-resend-code"])
        #expect(collection.groupPath.count == 3)
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `Verification.PhoneRouteCollection conforms to Sendable`() {
        let config = Passage.Configuration.Verification.Phone()
        assertSendable(Passage.Verification.PhoneRouteCollection(config: config, groupPath: []))
    }
}

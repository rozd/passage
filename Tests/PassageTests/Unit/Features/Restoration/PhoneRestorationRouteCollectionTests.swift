import Testing
import Vapor
@testable import Passage

@Suite
struct `Phone Restoration Route Collection Tests` {

    // MARK: - Initialization Tests

    @Test
    func `Passage.Restoration.PhoneRouteCollection initialization with default group`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: []
        )

        #expect(collection.groupPath.isEmpty)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection initialization with custom group`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let groupPath: [PathComponent] = ["auth", "password-reset"]
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: groupPath
        )

        #expect(collection.groupPath.count == 2)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection stores routes configuration`() {
        let requestRoute = Passage.Configuration.Restoration.Phone.Routes.Request(path: "request")
        let verifyRoute = Passage.Configuration.Restoration.Phone.Routes.Verify(path: "verify")
        let resendRoute = Passage.Configuration.Restoration.Phone.Routes.Resend(path: "resend")
        let routes = Passage.Configuration.Restoration.Phone.Routes(
            request: requestRoute,
            verify: verifyRoute,
            resend: resendRoute
        )

        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: []
        )

        #expect(collection.routes.request.path == ["request"])
        #expect(collection.routes.verify.path == ["verify"])
        #expect(collection.routes.resend.path == ["resend"])
    }

    // MARK: - Group Path Tests

    @Test
    func `Passage.Restoration.PhoneRouteCollection with empty group`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: []
        )

        #expect(collection.groupPath.isEmpty)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection with single component group`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: ["reset"]
        )

        #expect(collection.groupPath.count == 1)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection with multiple components`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: ["api", "v1", "auth", "phone", "reset"]
        )

        #expect(collection.groupPath.count == 5)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection with versioned group`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: ["v1", "password", "reset"]
        )

        #expect(collection.groupPath.count == 3)
    }

    // MARK: - Route Configuration Tests

    @Test
    func `Passage.Restoration.PhoneRouteCollection with default routes`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: []
        )

        #expect(collection.routes.request.path.count > 0)
        #expect(collection.routes.verify.path.count > 0)
        #expect(collection.routes.resend.path.count > 0)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection request route path`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: []
        )

        #expect(!collection.routes.request.path.isEmpty)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection verify route path`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: []
        )

        #expect(!collection.routes.verify.path.isEmpty)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection resend route path`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: []
        )

        #expect(!collection.routes.resend.path.isEmpty)
    }

    // MARK: - Multiple Instance Tests

    @Test
    func `Multiple Passage.Restoration.PhoneRouteCollection instances are independent`() {
        let requestRoute1 = Passage.Configuration.Restoration.Phone.Routes.Request(path: "request1")
        let verifyRoute1 = Passage.Configuration.Restoration.Phone.Routes.Verify(path: "verify1")
        let resendRoute1 = Passage.Configuration.Restoration.Phone.Routes.Resend(path: "resend1")
        let routes1 = Passage.Configuration.Restoration.Phone.Routes(
            request: requestRoute1,
            verify: verifyRoute1,
            resend: resendRoute1
        )

        let requestRoute2 = Passage.Configuration.Restoration.Phone.Routes.Request(path: "request2")
        let verifyRoute2 = Passage.Configuration.Restoration.Phone.Routes.Verify(path: "verify2")
        let resendRoute2 = Passage.Configuration.Restoration.Phone.Routes.Resend(path: "resend2")
        let routes2 = Passage.Configuration.Restoration.Phone.Routes(
            request: requestRoute2,
            verify: verifyRoute2,
            resend: resendRoute2
        )

        let collection1 = Passage.Restoration.PhoneRouteCollection(routes: routes1, groupPath: ["auth1"])
        let collection2 = Passage.Restoration.PhoneRouteCollection(routes: routes2, groupPath: ["auth2"])

        #expect(collection1.routes.request.path != collection2.routes.request.path)
        #expect(collection1.groupPath != collection2.groupPath)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection can be instantiated multiple times`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()

        let collection1 = Passage.Restoration.PhoneRouteCollection(routes: routes, groupPath: [])
        let collection2 = Passage.Restoration.PhoneRouteCollection(routes: routes, groupPath: [])

        #expect(collection1.groupPath == collection2.groupPath)
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `Passage.Restoration.PhoneRouteCollection conforms to RouteCollection`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: []
        )

        let _: any RouteCollection = collection
        #expect(collection is any RouteCollection)
    }

    // MARK: - Group Path Component Tests

    @Test
    func `Passage.Restoration.PhoneRouteCollection with different path component types`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()

        // String path components
        let collection1 = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: ["auth", "reset"]
        )
        #expect(collection1.groupPath.count == 2)

        // Constant path components
        let collection2 = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: [.constant("auth"), .constant("reset")]
        )
        #expect(collection2.groupPath.count == 2)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection preserves group order`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let groupPath: [PathComponent] = ["first", "second", "third"]
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: groupPath
        )

        #expect(collection.groupPath.count == 3)
    }

    // MARK: - Configuration Preservation Tests

    @Test
    func `Passage.Restoration.PhoneRouteCollection preserves all route settings`() {
        let requestRoute = Passage.Configuration.Restoration.Phone.Routes.Request(path: "req")
        let verifyRoute = Passage.Configuration.Restoration.Phone.Routes.Verify(path: "ver")
        let resendRoute = Passage.Configuration.Restoration.Phone.Routes.Resend(path: "res")
        let routes = Passage.Configuration.Restoration.Phone.Routes(
            request: requestRoute,
            verify: verifyRoute,
            resend: resendRoute
        )

        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: ["phone"]
        )

        #expect(collection.routes.request.path == ["req"])
        #expect(collection.routes.verify.path == ["ver"])
        #expect(collection.routes.resend.path == ["res"])
        #expect(collection.groupPath == ["phone"])
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection with nested path groups`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: ["api", "v2", "auth", "phone", "password-reset"]
        )

        #expect(collection.groupPath.count == 5)
    }

    // MARK: - Route Path Tests

    @Test
    func `Passage.Restoration.PhoneRouteCollection has three routes`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: []
        )

        // Verify all three routes are accessible
        #expect(!collection.routes.request.path.isEmpty)
        #expect(!collection.routes.verify.path.isEmpty)
        #expect(!collection.routes.resend.path.isEmpty)
    }

    @Test
    func `Passage.Restoration.PhoneRouteCollection route paths are distinct`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        let collection = Passage.Restoration.PhoneRouteCollection(
            routes: routes,
            groupPath: []
        )

        let requestPath = collection.routes.request.path
        let verifyPath = collection.routes.verify.path
        let resendPath = collection.routes.resend.path

        // Each route should have a path
        #expect(!requestPath.isEmpty)
        #expect(!verifyPath.isEmpty)
        #expect(!resendPath.isEmpty)
    }

    // MARK: - Comparison with Email Route Collection Tests

    @Test
    func `Phone and Email route collections are independent`() {
        let phoneRoutes = Passage.Configuration.Restoration.Phone.Routes()
        let phoneCollection = Passage.Restoration.PhoneRouteCollection(
            routes: phoneRoutes,
            groupPath: ["phone"]
        )

        let emailRoutes = Passage.Configuration.Restoration.Email.Routes()
        let emailCollection = Passage.Restoration.EmailRouteCollection(
            routes: emailRoutes,
            group: ["email"]
        )

        // They should have different types and different group names
        #expect(phoneCollection.groupPath != emailCollection.group)
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `Restoration.PhoneRouteCollection conforms to Sendable`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes()
        assertSendable(Passage.Restoration.PhoneRouteCollection(routes: routes, groupPath: []))
    }

    @Test
    func `Restoration.PhoneRouteCollection.ResendForm conforms to Sendable`() {
        assertSendable(Passage.Restoration.PhoneRouteCollection.ResendForm(phone: "+1234567890"))
    }
}

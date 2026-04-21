import Testing
import Vapor
@testable import Passage

@Suite
struct `Email Restoration Route Collection Tests` {

    // MARK: - Initialization Tests

    @Test
    func `Passage.Restoration.EmailRouteCollection initialization with default group`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: []
        )

        #expect(collection.group.isEmpty)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection initialization with custom group`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let group: [PathComponent] = ["auth", "password-reset"]
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: group
        )

        #expect(collection.group.count == 2)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection stores routes configuration`() {
        let requestRoute = Passage.Configuration.Restoration.Email.Routes.Request(path: "request")
        let verifyRoute = Passage.Configuration.Restoration.Email.Routes.Verify(path: "verify")
        let resendRoute = Passage.Configuration.Restoration.Email.Routes.Resend(path: "resend")
        let routes = Passage.Configuration.Restoration.Email.Routes(
            request: requestRoute,
            verify: verifyRoute,
            resend: resendRoute
        )

        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: []
        )

        #expect(collection.routes.request.path == ["request"])
        #expect(collection.routes.verify.path == ["verify"])
        #expect(collection.routes.resend.path == ["resend"])
    }

    // MARK: - Group Path Tests

    @Test
    func `Passage.Restoration.EmailRouteCollection with empty group`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: []
        )

        #expect(collection.group.isEmpty)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection with single component group`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: ["reset"]
        )

        #expect(collection.group.count == 1)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection with multiple components`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: ["api", "v1", "auth", "email", "reset"]
        )

        #expect(collection.group.count == 5)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection with versioned group`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: ["v1", "password", "reset"]
        )

        #expect(collection.group.count == 3)
    }

    // MARK: - Route Configuration Tests

    @Test
    func `Passage.Restoration.EmailRouteCollection with default routes`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: []
        )

        #expect(collection.routes.request.path.count > 0)
        #expect(collection.routes.verify.path.count > 0)
        #expect(collection.routes.resend.path.count > 0)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection request route path`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: []
        )

        #expect(!collection.routes.request.path.isEmpty)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection verify route path`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: []
        )

        #expect(!collection.routes.verify.path.isEmpty)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection resend route path`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: []
        )

        #expect(!collection.routes.resend.path.isEmpty)
    }

    // MARK: - Multiple Instance Tests

    @Test
    func `Multiple Passage.Restoration.EmailRouteCollection instances are independent`() {
        let requestRoute1 = Passage.Configuration.Restoration.Email.Routes.Request(path: "request1")
        let verifyRoute1 = Passage.Configuration.Restoration.Email.Routes.Verify(path: "verify1")
        let resendRoute1 = Passage.Configuration.Restoration.Email.Routes.Resend(path: "resend1")
        let routes1 = Passage.Configuration.Restoration.Email.Routes(
            request: requestRoute1,
            verify: verifyRoute1,
            resend: resendRoute1
        )

        let requestRoute2 = Passage.Configuration.Restoration.Email.Routes.Request(path: "request2")
        let verifyRoute2 = Passage.Configuration.Restoration.Email.Routes.Verify(path: "verify2")
        let resendRoute2 = Passage.Configuration.Restoration.Email.Routes.Resend(path: "resend2")
        let routes2 = Passage.Configuration.Restoration.Email.Routes(
            request: requestRoute2,
            verify: verifyRoute2,
            resend: resendRoute2
        )

        let collection1 = Passage.Restoration.EmailRouteCollection(routes: routes1, group: ["auth1"])
        let collection2 = Passage.Restoration.EmailRouteCollection(routes: routes2, group: ["auth2"])

        #expect(collection1.routes.request.path != collection2.routes.request.path)
        #expect(collection1.group != collection2.group)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection can be instantiated multiple times`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()

        let collection1 = Passage.Restoration.EmailRouteCollection(routes: routes, group: [])
        let collection2 = Passage.Restoration.EmailRouteCollection(routes: routes, group: [])

        #expect(collection1.group == collection2.group)
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `Passage.Restoration.EmailRouteCollection conforms to RouteCollection`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: []
        )

        let _: any RouteCollection = collection
        #expect(collection is any RouteCollection)
    }

    // MARK: - Group Path Component Tests

    @Test
    func `Passage.Restoration.EmailRouteCollection with different path component types`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()

        // String path components
        let collection1 = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: ["auth", "reset"]
        )
        #expect(collection1.group.count == 2)

        // Constant path components
        let collection2 = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: [.constant("auth"), .constant("reset")]
        )
        #expect(collection2.group.count == 2)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection preserves group order`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let group: [PathComponent] = ["first", "second", "third"]
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: group
        )

        #expect(collection.group.count == 3)
    }

    // MARK: - Configuration Preservation Tests

    @Test
    func `Passage.Restoration.EmailRouteCollection preserves all route settings`() {
        let requestRoute = Passage.Configuration.Restoration.Email.Routes.Request(path: "req")
        let verifyRoute = Passage.Configuration.Restoration.Email.Routes.Verify(path: "ver")
        let resendRoute = Passage.Configuration.Restoration.Email.Routes.Resend(path: "res")
        let routes = Passage.Configuration.Restoration.Email.Routes(
            request: requestRoute,
            verify: verifyRoute,
            resend: resendRoute
        )

        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: ["email"]
        )

        #expect(collection.routes.request.path == ["req"])
        #expect(collection.routes.verify.path == ["ver"])
        #expect(collection.routes.resend.path == ["res"])
        #expect(collection.group == ["email"])
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection with nested path groups`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: ["api", "v2", "auth", "email", "password-reset"]
        )

        #expect(collection.group.count == 5)
    }

    // MARK: - Route Path Tests

    @Test
    func `Passage.Restoration.EmailRouteCollection has three routes`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: []
        )

        // Verify all three routes are accessible
        #expect(!collection.routes.request.path.isEmpty)
        #expect(!collection.routes.verify.path.isEmpty)
        #expect(!collection.routes.resend.path.isEmpty)
    }

    @Test
    func `Passage.Restoration.EmailRouteCollection route paths are distinct`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        let collection = Passage.Restoration.EmailRouteCollection(
            routes: routes,
            group: []
        )

        let requestPath = collection.routes.request.path
        let verifyPath = collection.routes.verify.path
        let resendPath = collection.routes.resend.path

        // Each route should have a path
        #expect(!requestPath.isEmpty)
        #expect(!verifyPath.isEmpty)
        #expect(!resendPath.isEmpty)
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `Restoration.EmailRouteCollection conforms to Sendable`() {
        let routes = Passage.Configuration.Restoration.Email.Routes()
        assertSendable(Passage.Restoration.EmailRouteCollection(routes: routes, group: []))
    }
}

import Testing
import Vapor
@testable import Passage

@Suite(.tags(.unit))
struct `Account Route Collection Tests` {

    // MARK: - Initialization Tests

    @Test
    func `Passage.Account.RouteCollection initialization with default routes`() {
        let routes = Passage.Configuration.Routes()
        let collection = Passage.Account.RouteCollection(routes: routes)

        #expect(collection.routes.register.path.count == 1)
        #expect(collection.routes.login.path.count == 1)
        #expect(collection.routes.logout.path.count == 1)
        #expect(collection.routes.currentUser.path.count == 1)
    }

    @Test
    func `Passage.Account.RouteCollection initialization with custom routes`() {
        let routes = Passage.Configuration.Routes(
            register: .init(path: "signup"),
            login: .init(path: "signin"),
            logout: .init(path: "signout"),
            currentUser: .init(path: "user", "profile")
        )
        let collection = Passage.Account.RouteCollection(routes: routes)

        #expect(collection.routes.register.path.count == 1)
        #expect(collection.routes.register.path[0] == PathComponent.constant("signup"))
        #expect(collection.routes.login.path[0] == PathComponent.constant("signin"))
        #expect(collection.routes.logout.path[0] == PathComponent.constant("signout"))
        #expect(collection.routes.currentUser.path.count == 2)
    }

    @Test
    func `Passage.Account.RouteCollection stores routes configuration`() {
        let routes = Passage.Configuration.Routes(
            group: "api", "v1"
        )
        let collection = Passage.Account.RouteCollection(routes: routes)

        #expect(collection.routes.group.count == 2)
        #expect(collection.routes.group[0] == PathComponent.constant("api"))
        #expect(collection.routes.group[1] == PathComponent.constant("v1"))
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `Passage.Account.RouteCollection conforms to RouteCollection`() {
        let routes = Passage.Configuration.Routes()
        let collection = Passage.Account.RouteCollection(routes: routes)

        let _: any RouteCollection = collection
    }

    // MARK: - Route Path Configuration Tests

    @Test
    func `Passage.Account.RouteCollection with no group`() {
        let routes = Passage.Configuration.Routes()
        let collection = Passage.Account.RouteCollection(routes: routes)

        #expect(collection.routes.group.count == 1)
        #expect(collection.routes.group[0] == PathComponent.constant("auth"))
    }

    @Test
    func `Passage.Account.RouteCollection with auth group`() {
        let routes = Passage.Configuration.Routes(group: "auth")
        let collection = Passage.Account.RouteCollection(routes: routes)

        #expect(collection.routes.group.count == 1)
        #expect(collection.routes.group[0] == PathComponent.constant("auth"))
    }

    @Test
    func `Passage.Account.RouteCollection with nested group`() {
        let routes = Passage.Configuration.Routes(group: "api", "auth")
        let collection = Passage.Account.RouteCollection(routes: routes)

        #expect(collection.routes.group.count == 2)
        #expect(collection.routes.group[0] == PathComponent.constant("api"))
        #expect(collection.routes.group[1] == PathComponent.constant("auth"))
    }

    @Test
    func `Passage.Account.RouteCollection with versioned group`() {
        let routes = Passage.Configuration.Routes(group: "v1", "account")
        let collection = Passage.Account.RouteCollection(routes: routes)

        #expect(collection.routes.group.count == 2)
        #expect(collection.routes.group[0] == PathComponent.constant("v1"))
        #expect(collection.routes.group[1] == PathComponent.constant("account"))
    }

    @Test
    func `Passage.Account.RouteCollection default route paths`() {
        let routes = Passage.Configuration.Routes()
        let collection = Passage.Account.RouteCollection(routes: routes)

        // Verify default paths match configuration defaults
        #expect(collection.routes.register.path == [PathComponent.constant("register")])
        #expect(collection.routes.login.path == [PathComponent.constant("login")])
        #expect(collection.routes.logout.path == [PathComponent.constant("logout")])
        #expect(collection.routes.currentUser.path == [PathComponent.constant("me")])
    }

    @Test
    func `Passage.Account.RouteCollection with custom path components`() {
        let routes = Passage.Configuration.Routes(
            register: .init(path: "users", "create"),
            login: .init(path: "auth", "login"),
            logout: .init(path: "auth", "logout"),
            currentUser: .init(path: "users", "me")
        )
        let collection = Passage.Account.RouteCollection(routes: routes)

        #expect(collection.routes.register.path.count == 2)
        #expect(collection.routes.login.path.count == 2)
        #expect(collection.routes.logout.path.count == 2)
        #expect(collection.routes.currentUser.path.count == 2)
    }

    @Test
    func `Passage.Account.RouteCollection preserves route configuration`() {
        let customRegister = Passage.Configuration.Routes.Register(path: "custom", "register")
        let customLogin = Passage.Configuration.Routes.Login(path: "custom", "login")

        let routes = Passage.Configuration.Routes(
            register: customRegister,
            login: customLogin
        )
        let collection = Passage.Account.RouteCollection(routes: routes)

        // Verify the collection preserves the exact route configuration
        #expect(collection.routes.register.path == customRegister.path)
        #expect(collection.routes.login.path == customLogin.path)
    }

    // MARK: - Multiple Instance Tests

    @Test
    func `Passage.Account.RouteCollection can be instantiated multiple times`() {
        let routes1 = Passage.Configuration.Routes(group: "api")
        let routes2 = Passage.Configuration.Routes(group: "admin")

        let collection1 = Passage.Account.RouteCollection(routes: routes1)
        let collection2 = Passage.Account.RouteCollection(routes: routes2)

        #expect(collection1.routes.group[0] == PathComponent.constant("api"))
        #expect(collection2.routes.group[0] == PathComponent.constant("admin"))
    }

    @Test
    func `Passage.Account.RouteCollection instances are independent`() {
        let routes1 = Passage.Configuration.Routes(
            register: .init(path: "register1")
        )
        let routes2 = Passage.Configuration.Routes(
            register: .init(path: "register2")
        )

        let collection1 = Passage.Account.RouteCollection(routes: routes1)
        let collection2 = Passage.Account.RouteCollection(routes: routes2)

        #expect(collection1.routes.register.path[0] == PathComponent.constant("register1"))
        #expect(collection2.routes.register.path[0] == PathComponent.constant("register2"))
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `Account.RouteCollection conforms to Sendable`() {
        let routes = Passage.Configuration.Routes()
        assertSendable(Passage.Account.RouteCollection(routes: routes))
    }
}

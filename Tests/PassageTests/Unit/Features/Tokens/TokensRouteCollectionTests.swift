import Testing
import Vapor
@testable import Passage

@Suite(.tags(.unit))
struct `Tokens Route Collection Tests` {

    // MARK: - Initialization Tests

    @Test
    func `Passage.Tokens.RouteCollection initialization with default routes`() {
        let routes = Passage.Configuration.Routes()
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.refreshToken.path.count == 1)
    }

    @Test
    func `Passage.Tokens.RouteCollection initialization with custom routes`() {
        let routes = Passage.Configuration.Routes(
            refreshToken: .init(path: "token", "refresh")
        )
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.refreshToken.path.count == 2)
        #expect(collection.routes.refreshToken.path[0] == PathComponent.constant("token"))
        #expect(collection.routes.refreshToken.path[1] == PathComponent.constant("refresh"))
    }

    @Test
    func `Passage.Tokens.RouteCollection stores routes configuration`() {
        let routes = Passage.Configuration.Routes(
            group: "api", "v1"
        )
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.group.count == 2)
        #expect(collection.routes.group[0] == PathComponent.constant("api"))
        #expect(collection.routes.group[1] == PathComponent.constant("v1"))
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `Passage.Tokens.RouteCollection conforms to RouteCollection`() {
        let routes = Passage.Configuration.Routes()
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        let _: any RouteCollection = collection
    }

    // MARK: - Route Path Configuration Tests

    @Test
    func `Passage.Tokens.RouteCollection with no group`() {
        let routes = Passage.Configuration.Routes()
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.group.count == 1)
        #expect(collection.routes.group[0] == PathComponent.constant("auth"))
    }

    @Test
    func `Passage.Tokens.RouteCollection with auth group`() {
        let routes = Passage.Configuration.Routes(group: "auth")
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.group.count == 1)
        #expect(collection.routes.group[0] == PathComponent.constant("auth"))
    }

    @Test
    func `Passage.Tokens.RouteCollection with nested group`() {
        let routes = Passage.Configuration.Routes(group: "api", "auth")
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.group.count == 2)
        #expect(collection.routes.group[0] == PathComponent.constant("api"))
        #expect(collection.routes.group[1] == PathComponent.constant("auth"))
    }

    @Test
    func `Passage.Tokens.RouteCollection default route paths`() {
        let routes = Passage.Configuration.Routes()
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        // Verify default paths match configuration defaults
        #expect(collection.routes.refreshToken.path == [PathComponent.constant("refresh-token")])
    }

    @Test
    func `Passage.Tokens.RouteCollection with custom path components`() {
        let routes = Passage.Configuration.Routes(
            refreshToken: .init(path: "auth", "refresh")
        )
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.refreshToken.path.count == 2)
    }

    @Test
    func `Passage.Tokens.RouteCollection preserves route configuration`() {
        let customRefreshToken = Passage.Configuration.Routes.RefreshToken(path: "custom", "refresh")

        let routes = Passage.Configuration.Routes(
            refreshToken: customRefreshToken
        )
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        // Verify the collection preserves the exact route configuration
        #expect(collection.routes.refreshToken.path == customRefreshToken.path)
    }

    // MARK: - Multiple Instance Tests

    @Test
    func `Passage.Tokens.RouteCollection can be instantiated multiple times`() {
        let routes1 = Passage.Configuration.Routes(group: "api")
        let routes2 = Passage.Configuration.Routes(group: "admin")

        let collection1 = Passage.Tokens.RouteCollection(routes: routes1)
        let collection2 = Passage.Tokens.RouteCollection(routes: routes2)

        #expect(collection1.routes.group[0] == PathComponent.constant("api"))
        #expect(collection2.routes.group[0] == PathComponent.constant("admin"))
    }

    @Test
    func `Passage.Tokens.RouteCollection instances are independent`() {
        let routes1 = Passage.Configuration.Routes(
            refreshToken: .init(path: "refresh1")
        )
        let routes2 = Passage.Configuration.Routes(
            refreshToken: .init(path: "refresh2")
        )

        let collection1 = Passage.Tokens.RouteCollection(routes: routes1)
        let collection2 = Passage.Tokens.RouteCollection(routes: routes2)

        #expect(collection1.routes.refreshToken.path[0] == PathComponent.constant("refresh1"))
        #expect(collection2.routes.refreshToken.path[0] == PathComponent.constant("refresh2"))
    }

    // MARK: - Exchange Code Route Tests

    @Test
    func `Passage.Tokens.RouteCollection default exchange code path`() {
        let routes = Passage.Configuration.Routes()
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.exchangeCode.path.count == 2)
        #expect(collection.routes.exchangeCode.path[0] == PathComponent.constant("token"))
        #expect(collection.routes.exchangeCode.path[1] == PathComponent.constant("exchange"))
    }

    @Test
    func `Passage.Tokens.RouteCollection with custom exchange code path`() {
        let routes = Passage.Configuration.Routes(
            exchangeCode: .init(path: "oauth", "callback", "exchange")
        )
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.exchangeCode.path.count == 3)
        #expect(collection.routes.exchangeCode.path[0] == PathComponent.constant("oauth"))
        #expect(collection.routes.exchangeCode.path[1] == PathComponent.constant("callback"))
        #expect(collection.routes.exchangeCode.path[2] == PathComponent.constant("exchange"))
    }

    @Test
    func `Passage.Tokens.RouteCollection preserves exchange code with other routes`() {
        let customRefreshToken = Passage.Configuration.Routes.RefreshToken(path: "custom", "refresh")
        let customExchangeCode = Passage.Configuration.Routes.ExchangeCode(path: "custom", "exchange")

        let routes = Passage.Configuration.Routes(
            refreshToken: customRefreshToken,
            exchangeCode: customExchangeCode
        )
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.refreshToken.path == customRefreshToken.path)
        #expect(collection.routes.exchangeCode.path == customExchangeCode.path)
    }

    @Test
    func `Passage.Tokens.RouteCollection exchange code with group`() {
        let routes = Passage.Configuration.Routes(
            group: "api", "auth"
        )
        let collection = Passage.Tokens.RouteCollection(routes: routes)

        #expect(collection.routes.group.count == 2)
        #expect(collection.routes.exchangeCode.path.count == 2)
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `Tokens.RouteCollection conforms to Sendable`() {
        let routes = Passage.Configuration.Routes()
        assertSendable(Passage.Tokens.RouteCollection(routes: routes))
    }
}

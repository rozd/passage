import Testing
import Foundation
import Vapor
@testable import Passage

@Suite
struct `Federated Login Configuration Tests` {

    // MARK: - FederatedLogin Routes Tests

    @Test
    func `FederatedLogin routes default group`() {
        let routes = Passage.Configuration.FederatedLogin.Routes()

        #expect(routes.group.count == 1)
        #expect(routes.group[0].description == "connect")
    }

    @Test
    func `FederatedLogin routes custom group`() {
        let routes = Passage.Configuration.FederatedLogin.Routes(group: "api", "auth", "social")

        #expect(routes.group.count == 3)
        #expect(routes.group[0].description == "api")
        #expect(routes.group[1].description == "auth")
        #expect(routes.group[2].description == "social")
    }

    // MARK: - FederatedLogin Configuration Tests

    @Test
    func `FederatedLogin default configuration`() {
        let config = Passage.Configuration.FederatedLogin(routes: .init(), providers: [])

        #expect(config.routes.group[0].description == "connect")
        #expect(config.providers.isEmpty)
        #expect(config.redirectLocation == "/")
    }

    @Test
    func `FederatedLogin with custom redirect`() {
        let config = Passage.Configuration.FederatedLogin(
            routes: .init(),
            providers: [],
            redirectLocation: "/dashboard"
        )

        #expect(config.redirectLocation == "/dashboard")
    }

    @Test
    func `FederatedLogin with providers`() {
        let config = Passage.Configuration.FederatedLogin(
            routes: .init(),
            providers: [
                .init(provider: .google()),
                .init(provider: .github())
            ]
        )

        #expect(config.providers.count == 2)
        #expect(config.providers[0].provider.name == .google)
        #expect(config.providers[1].provider.name == .github)
    }

    // MARK: - Path Helper Tests

    @Test
    func `Login path for provider`() {
        let provider = Passage.Configuration.FederatedLogin.Provider(
            provider: .google(),
        )
        let config = Passage.Configuration.FederatedLogin(
            routes: .init(group: "api", "oauth"),
            providers: [
                provider
            ]
        )

        let path = config.loginPath(for: provider)

        #expect(path.count == 3)
        #expect(path[0].description == "api")
        #expect(path[1].description == "oauth")
        #expect(path[2].description == "google")
    }

    @Test
    func `Callback path for provider`() {
        let provider = Passage.Configuration.FederatedLogin.Provider(
            provider: .github(),
        )
        let config = Passage.Configuration.FederatedLogin(
            routes: .init(group: "auth"),
            providers: [provider]
        )

        let path = config.callbackPath(for: provider)

        #expect(path.count == 3)
        #expect(path[0].description == "auth")
        #expect(path[1].description == "github")
        #expect(path[2].description == "callback")
    }

    @Test
    func `Custom provider paths`() {
        let customRoutes = Passage.Configuration.FederatedLogin.Provider.Routes(
            login: .init(path: "custom", "login"),
            callback: .init(path: "custom", "cb")
        )

        let provider = Passage.Configuration.FederatedLogin.Provider(
            provider: .custom(name: "custom"),
            routes: customRoutes
        )

        let config = Passage.Configuration.FederatedLogin(
            routes: .init(),
            providers: [provider]
        )

        let loginPath = config.loginPath(for: provider)
        let callbackPath = config.callbackPath(for: provider)

        #expect(loginPath[1].description == "custom")
        #expect(loginPath[2].description == "login")
        #expect(callbackPath[1].description == "custom")
        #expect(callbackPath[2].description == "cb")
    }

    @Test
    func `FederatedLogin Sendable conformance`() {
        let federatedLogin: Passage.Configuration.FederatedLogin = .init(
            routes: .init(),
            providers: []
        )

        let _: any Sendable = federatedLogin
        let _: any Sendable = federatedLogin.routes
    }

    // MARK: - Provider Routes Tests

    @Test
    func `Provider Routes Login initialization with variadic path`() {
        let login = Passage.Configuration.FederatedLogin.Provider.Routes.Login(path: "oauth", "google")
        #expect(login.path.count == 2)
    }

    @Test
    func `Provider Routes Login initialization with array path`() {
        let path: [PathComponent] = ["oauth", "google"]
        let login = Passage.Configuration.FederatedLogin.Provider.Routes.Login(path: path)
        #expect(login.path.count == 2)
    }

    @Test
    func `Provider Routes Callback initialization with variadic path`() {
        let callback = Passage.Configuration.FederatedLogin.Provider.Routes.Callback(path: "oauth", "callback")
        #expect(callback.path.count == 2)
    }

    @Test
    func `Provider Routes Callback initialization with array path`() {
        let path: [PathComponent] = ["oauth", "callback"]
        let callback = Passage.Configuration.FederatedLogin.Provider.Routes.Callback(path: path)
        #expect(callback.path.count == 2)
    }

    @Test
    func `Provider Routes default initialization`() {
        let routes = Passage.Configuration.FederatedLogin.Provider.Routes()

        #expect(routes.login.path.isEmpty)
        #expect(routes.callback.path == ["callback"])
    }

    @Test
    func `Provider Routes custom initialization`() {
        let login = Passage.Configuration.FederatedLogin.Provider.Routes.Login(path: "auth", "login")
        let callback = Passage.Configuration.FederatedLogin.Provider.Routes.Callback(path: "auth", "callback")
        let routes = Passage.Configuration.FederatedLogin.Provider.Routes(login: login, callback: callback)

        #expect(routes.login.path == ["auth", "login"])
        #expect(routes.callback.path == ["auth", "callback"])
    }

    @Test
    func `Provider Routes conforms to Sendable`() {
        let _: any Sendable.Type = Passage.Configuration.FederatedLogin.Provider.Routes.self
    }

    // MARK: - Provider Nested Type Tests

    @Test
    func `Provider Routes is nested within Provider`() {
        let typeName = String(reflecting: Passage.Configuration.FederatedLogin.Provider.Routes.self)
        #expect(typeName.contains("Passage.Configuration.FederatedLogin.Provider.Routes"))
    }

    // MARK: - Routes Nested Types Tests

    @Test
    func `Routes Login is nested within Routes`() {
        let typeName = String(reflecting: Passage.Configuration.FederatedLogin.Provider.Routes.Login.self)
        #expect(typeName.contains("Passage.Configuration.FederatedLogin.Provider.Routes.Login"))
    }

    @Test
    func `Routes Callback is nested within Routes`() {
        let typeName = String(reflecting: Passage.Configuration.FederatedLogin.Provider.Routes.Callback.self)
        #expect(typeName.contains("Passage.Configuration.FederatedLogin.Provider.Routes.Callback"))
    }

    // MARK: - Integration Tests


    @Test
    func `Provider with different route configurations`() {
        let defaultRoutes = Passage.Configuration.FederatedLogin.Provider(
            provider: .google()
        )

        let customLogin = Passage.Configuration.FederatedLogin.Provider.Routes.Login(path: "custom", "login")
        let customCallback = Passage.Configuration.FederatedLogin.Provider.Routes.Callback(path: "custom", "callback")
        let customRoutes = Passage.Configuration.FederatedLogin.Provider.Routes(login: customLogin, callback: customCallback)

        let withCustomRoutes = Passage.Configuration.FederatedLogin.Provider(
            provider: .google(),
            routes: customRoutes
        )


        #expect(defaultRoutes.routes.login.path == ["google"])
        #expect(withCustomRoutes.routes.login.path == ["custom", "login"])
    }

    // MARK: - Routes Path Component Tests

    @Test
    func `Routes Login stores path components`() {
        let login = Passage.Configuration.FederatedLogin.Provider.Routes.Login(path: "a", "b", "c")
        #expect(login.path.count == 3)
    }

    @Test
    func `Routes Callback stores path components`() {
        let callback = Passage.Configuration.FederatedLogin.Provider.Routes.Callback(path: "x", "y", "z")
        #expect(callback.path.count == 3)
    }

    @Test
    func `Routes with empty path components`() {
        let login = Passage.Configuration.FederatedLogin.Provider.Routes.Login(path: [])
        let callback = Passage.Configuration.FederatedLogin.Provider.Routes.Callback(path: [])

        #expect(login.path.isEmpty)
        #expect(callback.path.isEmpty)
    }

    @Test
    func `Provider google() with custom routes`() {
        let login = Passage.Configuration.FederatedLogin.Provider.Routes.Login(path: "auth", "google")
        let callback = Passage.Configuration.FederatedLogin.Provider.Routes.Callback(path: "auth", "google", "callback")
        let routes = Passage.Configuration.FederatedLogin.Provider.Routes(login: login, callback: callback)

        let provider = Passage.Configuration.FederatedLogin.Provider(
            provider: .google(),
            routes: routes
        )

        #expect(provider.routes.login.path == ["auth", "google"])
        #expect(provider.routes.callback.path == ["auth", "google", "callback"])
    }

}

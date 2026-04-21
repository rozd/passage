import Testing
import Foundation
import Vapor
@testable import Passage

@Suite
struct `Routes Configuration Tests` {

    // MARK: - Register Route Tests

    @Test
    func `Register route default path`() {
        let route = Passage.Configuration.Routes.Register.default
        #expect(route.path.count == 1)
        #expect(route.path[0].description == "register")
    }

    @Test
    func `Register route custom path`() {
        let route = Passage.Configuration.Routes.Register(path: "api", "v1", "signup")
        #expect(route.path.count == 3)
        #expect(route.path[0].description == "api")
        #expect(route.path[1].description == "v1")
        #expect(route.path[2].description == "signup")
    }

    // MARK: - Login Route Tests

    @Test
    func `Login route default path`() {
        let route = Passage.Configuration.Routes.Login.default
        #expect(route.path.count == 1)
        #expect(route.path[0].description == "login")
    }

    @Test
    func `Login route custom path`() {
        let route = Passage.Configuration.Routes.Login(path: "signin")
        #expect(route.path.count == 1)
        #expect(route.path[0].description == "signin")
    }

    // MARK: - Logout Route Tests

    @Test
    func `Logout route default path`() {
        let route = Passage.Configuration.Routes.Logout.default
        #expect(route.path.count == 1)
        #expect(route.path[0].description == "logout")
    }

    @Test
    func `Logout route custom path`() {
        let route = Passage.Configuration.Routes.Logout(path: "signout")
        #expect(route.path.count == 1)
        #expect(route.path[0].description == "signout")
    }

    // MARK: - RefreshToken Route Tests

    @Test
    func `Refresh token route default path`() {
        let route = Passage.Configuration.Routes.RefreshToken.default
        #expect(route.path.count == 1)
        #expect(route.path[0].description == "refresh-token")
    }

    @Test
    func `Refresh token route custom path`() {
        let route = Passage.Configuration.Routes.RefreshToken(path: "token", "refresh")
        #expect(route.path.count == 2)
        #expect(route.path[0].description == "token")
        #expect(route.path[1].description == "refresh")
    }

    // MARK: - CurrentUser Route Tests

    @Test
    func `Current user route default path`() {
        let route = Passage.Configuration.Routes.CurrentUser.default
        #expect(route.path.count == 1)
        #expect(route.path[0].description == "me")
    }

    @Test
    func `Current user route custom path`() {
        let route = Passage.Configuration.Routes.CurrentUser(path: "user", "profile")
        #expect(route.path.count == 2)
        #expect(route.path[0].description == "user")
        #expect(route.path[1].description == "profile")
    }

    // MARK: - Routes Configuration Tests

    @Test
    func `Routes default configuration`() {
        let routes = Passage.Configuration.Routes()

        #expect(routes.group.count == 1)
        #expect(routes.group[0].description == "auth")
        #expect(routes.register.path[0].description == "register")
        #expect(routes.login.path[0].description == "login")
        #expect(routes.logout.path[0].description == "logout")
        #expect(routes.refreshToken.path[0].description == "refresh-token")
        #expect(routes.currentUser.path[0].description == "me")
    }

    @Test
    func `Routes with custom group`() {
        let routes = Passage.Configuration.Routes(group: "api", "v1")

        #expect(routes.group.count == 2)
        #expect(routes.group[0].description == "api")
        #expect(routes.group[1].description == "v1")
    }

    @Test
    func `Routes with custom paths`() {
        let routes = Passage.Configuration.Routes(
            register: .init(path: "signup"),
            login: .init(path: "signin"),
            logout: .init(path: "signout"),
            refreshToken: .init(path: "token", "refresh"),
            currentUser: .init(path: "profile")
        )

        #expect(routes.register.path[0].description == "signup")
        #expect(routes.login.path[0].description == "signin")
        #expect(routes.logout.path[0].description == "signout")
        #expect(routes.refreshToken.path[0].description == "token")
        #expect(routes.refreshToken.path[1].description == "refresh")
        #expect(routes.currentUser.path[0].description == "profile")
    }

    @Test
    func `Routes with custom group and paths`() {
        let routes = Passage.Configuration.Routes(
            group: "api", "auth",
            register: .init(path: "signup"),
            login: .init(path: "signin")
        )

        #expect(routes.group.count == 2)
        #expect(routes.group[0].description == "api")
        #expect(routes.group[1].description == "auth")
        #expect(routes.register.path[0].description == "signup")
        #expect(routes.login.path[0].description == "signin")
    }

    @Test
    func `Routes Sendable conformance`() {
        let routes: Passage.Configuration.Routes = .init()

        let _: any Sendable = routes
        let _: any Sendable = routes.register
        let _: any Sendable = routes.login
        let _: any Sendable = routes.logout
        let _: any Sendable = routes.refreshToken
        let _: any Sendable = routes.currentUser
    }
}

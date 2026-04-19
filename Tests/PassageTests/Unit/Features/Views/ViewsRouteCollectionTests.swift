import Testing
import Vapor
@testable import Passage

@Suite("Views Route Collection Tests")
struct ViewsRouteCollectionTests {

    // MARK: - Initialization Tests

    @Test("Passage.Views.RouteCollection initialization")
    func routeCollectionInitialization() {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let loginView = Passage.Configuration.Views.LoginView(
            style: .neobrutalism,
            theme: theme,
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(
            register: nil,
            login: loginView,
            passwordResetRequest: nil,
            passwordResetConfirm: nil
        )
        let routesConfig = Passage.Configuration.Routes()
        let restorationConfig = Passage.Configuration.Restoration()

        let passwordlessConfig = Passage.Configuration.Passwordless()
        let federatedLoginConfig = Passage.Configuration.FederatedLogin(providers: [])
        let collection = Passage.Views.RouteCollection(
            group: [],
            config: viewsConfig,
            routes: routesConfig,
            restoration: restorationConfig,
            passwordless: passwordlessConfig,
            federatedLogin: federatedLoginConfig,
            passkey: nil
        )

        #expect(collection.group.isEmpty)
    }

    @Test("Passage.Views.RouteCollection initialization with custom group")
    func routeCollectionWithCustomGroup() {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let loginView = Passage.Configuration.Views.LoginView(
            style: .neobrutalism,
            theme: theme,
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(
            register: nil,
            login: loginView,
            passwordResetRequest: nil,
            passwordResetConfirm: nil
        )
        let routesConfig = Passage.Configuration.Routes()
        let restorationConfig = Passage.Configuration.Restoration()
        let groupPath: [PathComponent] = ["auth", "views"]

        let passwordlessConfig = Passage.Configuration.Passwordless()
        let federatedLoginConfig = Passage.Configuration.FederatedLogin(providers: [])
        let collection = Passage.Views.RouteCollection(
            group: groupPath,
            config: viewsConfig,
            routes: routesConfig,
            restoration: restorationConfig,
            passwordless: passwordlessConfig,
            federatedLogin: federatedLoginConfig,
            passkey: nil
        )

        #expect(collection.group.count == 2)
        #expect(collection.group[0] == PathComponent.constant("auth"))
        #expect(collection.group[1] == PathComponent.constant("views"))
    }

    @Test("Passage.Views.RouteCollection stores configuration references")
    func routeCollectionStoresConfig() {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let registerView = Passage.Configuration.Views.RegisterView(
            style: .minimalism,
            theme: theme,
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(
            register: registerView,
            login: nil,
            passwordResetRequest: nil,
            passwordResetConfirm: nil
        )
        let routesConfig = Passage.Configuration.Routes(
            register: .init(path: "custom", "register")
        )
        let restorationConfig = Passage.Configuration.Restoration()

        let passwordlessConfig = Passage.Configuration.Passwordless()
        let federatedLoginConfig = Passage.Configuration.FederatedLogin(providers: [])
        let collection = Passage.Views.RouteCollection(
            group: [],
            config: viewsConfig,
            routes: routesConfig,
            restoration: restorationConfig,
            passwordless: passwordlessConfig,
            federatedLogin: federatedLoginConfig,
            passkey: nil
        )

        #expect(collection.config.register?.style == .minimalism)
        #expect(collection.routes.register.path.count == 2)
    }

    @Test("Passage.Views.RouteCollection with all view types configured")
    func routeCollectionWithAllViews() {
        let theme = Passage.Views.Theme(colors: .oceanLight)
        let loginView = Passage.Configuration.Views.LoginView(
            style: .neobrutalism,
            theme: theme,
            identifier: .email
        )
        let registerView = Passage.Configuration.Views.RegisterView(
            style: .neomorphism,
            theme: theme,
            identifier: .email
        )
        let resetRequestView = Passage.Configuration.Views.PasswordResetRequestView(
            style: .minimalism,
            theme: theme
        )
        let resetConfirmView = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .material,
            theme: theme
        )

        let viewsConfig = Passage.Configuration.Views(
            register: registerView,
            login: loginView,
            passwordResetRequest: resetRequestView,
            passwordResetConfirm: resetConfirmView
        )
        let routesConfig = Passage.Configuration.Routes()
        let restorationConfig = Passage.Configuration.Restoration()

        let passwordlessConfig = Passage.Configuration.Passwordless()
        let federatedLoginConfig = Passage.Configuration.FederatedLogin(providers: [])
        let collection = Passage.Views.RouteCollection(
            group: [],
            config: viewsConfig,
            routes: routesConfig,
            restoration: restorationConfig,
            passwordless: passwordlessConfig,
            federatedLogin: federatedLoginConfig,
            passkey: nil
        )

        #expect(collection.config.login != nil)
        #expect(collection.config.register != nil)
        #expect(collection.config.passwordResetRequest != nil)
        #expect(collection.config.passwordResetConfirm != nil)
    }

    @Test("Passage.Views.RouteCollection with no views configured")
    func routeCollectionWithNoViews() {
        let viewsConfig = Passage.Configuration.Views(
            register: nil,
            login: nil,
            passwordResetRequest: nil,
            passwordResetConfirm: nil
        )
        let routesConfig = Passage.Configuration.Routes()
        let restorationConfig = Passage.Configuration.Restoration()

        let passwordlessConfig = Passage.Configuration.Passwordless()
        let federatedLoginConfig = Passage.Configuration.FederatedLogin(providers: [])
        let collection = Passage.Views.RouteCollection(
            group: [],
            config: viewsConfig,
            routes: routesConfig,
            restoration: restorationConfig,
            passwordless: passwordlessConfig,
            federatedLogin: federatedLoginConfig,
            passkey: nil
        )

        #expect(collection.config.login == nil)
        #expect(collection.config.register == nil)
        #expect(collection.config.passwordResetRequest == nil)
        #expect(collection.config.passwordResetConfirm == nil)
    }

    // MARK: - Protocol Conformance Tests

    @Test("Passage.Views.RouteCollection conforms to RouteCollection")
    func routeCollectionConformsToProtocol() {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let loginView = Passage.Configuration.Views.LoginView(
            style: .neobrutalism,
            theme: theme,
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(
            register: nil,
            login: loginView,
            passwordResetRequest: nil,
            passwordResetConfirm: nil
        )
        let routesConfig = Passage.Configuration.Routes()
        let restorationConfig = Passage.Configuration.Restoration()

        let passwordlessConfig = Passage.Configuration.Passwordless()
        let federatedLoginConfig = Passage.Configuration.FederatedLogin(providers: [])
        let collection = Passage.Views.RouteCollection(
            group: [],
            config: viewsConfig,
            routes: routesConfig,
            restoration: restorationConfig,
            passwordless: passwordlessConfig,
            federatedLogin: federatedLoginConfig,
            passkey: nil
        )

        let _: any RouteCollection = collection
    }

    // MARK: - Configuration Integration Tests

    @Test("Passage.Views.RouteCollection with custom restoration routes")
    func routeCollectionWithCustomRestorationRoutes() {
        let theme = Passage.Views.Theme(colors: .forestLight)
        let resetRequestView = Passage.Configuration.Views.PasswordResetRequestView(
            style: .material,
            theme: theme
        )
        let viewsConfig = Passage.Configuration.Views(
            register: nil,
            login: nil,
            passwordResetRequest: resetRequestView,
            passwordResetConfirm: nil
        )
        let routesConfig = Passage.Configuration.Routes()
        let restorationConfig = Passage.Configuration.Restoration(
            email: .init(
                routes: .init(
                    request: .init(path: "custom", "reset", "request"),
                    verify: .init(path: "custom", "reset", "verify")
                )
            )
        )

        let passwordlessConfig = Passage.Configuration.Passwordless()
        let federatedLoginConfig = Passage.Configuration.FederatedLogin(providers: [])
        let collection = Passage.Views.RouteCollection(
            group: [],
            config: viewsConfig,
            routes: routesConfig,
            restoration: restorationConfig,
            passwordless: passwordlessConfig,
            federatedLogin: federatedLoginConfig,
            passkey: nil
        )

        #expect(collection.restoration.email.routes.request.path.count == 3)
        #expect(collection.restoration.email.routes.verify.path.count == 3)
    }

    @Test("Passage.Views.RouteCollection group path variations", arguments: [
        ([], "empty group"),
        (["auth"] as [PathComponent], "single component"),
        (["api", "v1", "auth"] as [PathComponent], "multiple components"),
        (["views"] as [PathComponent], "views group")
    ])
    func routeCollectionGroupVariations(group: [PathComponent], _: String) {
        let viewsConfig = Passage.Configuration.Views(
            register: nil,
            login: nil,
            passwordResetRequest: nil,
            passwordResetConfirm: nil
        )
        let routesConfig = Passage.Configuration.Routes()
        let restorationConfig = Passage.Configuration.Restoration()
        let passwordlessConfig = Passage.Configuration.Passwordless()
        let federatedLoginConfig = Passage.Configuration.FederatedLogin(providers: [])

        let collection = Passage.Views.RouteCollection(
            group: group,
            config: viewsConfig,
            routes: routesConfig,
            restoration: restorationConfig,
            passwordless: passwordlessConfig,
            federatedLogin: federatedLoginConfig,
            passkey: nil
        )

        #expect(collection.group.count == group.count)
        for (index, component) in group.enumerated() {
            #expect(collection.group[index] == component)
        }
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test("Views.RouteCollection conforms to Sendable")
    func conformsToSendable() {
        let config = Passage.Configuration.Views()
        let routes = Passage.Configuration.Routes()
        let restoration = Passage.Configuration.Restoration()
        let passwordless = Passage.Configuration.Passwordless()
        let federatedLogin = Passage.Configuration.FederatedLogin(providers: [])
        assertSendable(Passage.Views.RouteCollection(
            group: [],
            config: config,
            routes: routes,
            restoration: restoration,
            passwordless: passwordless,
            federatedLogin: federatedLogin,
            passkey: nil
        ))
    }
}

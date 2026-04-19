import Testing
import Foundation
@testable import Passage

@Suite("Views Configuration Tests")
struct ViewsConfigurationTests {

    // MARK: - Test Helpers

    private func createTestTheme() -> Passage.Views.Theme {
        return Passage.Views.Theme(colors: .defaultLight)
    }

    // MARK: - Redirect Configuration Tests

    @Test("Redirect default configuration")
    func redirectDefault() {
        let redirect = Passage.Configuration.Views.Redirect()

        #expect(redirect.onSuccess == nil)
        #expect(redirect.onFailure == nil)
    }

    @Test("Redirect with success and failure paths")
    func redirectWithPaths() {
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: "/dashboard",
            onFailure: "/error"
        )

        #expect(redirect.onSuccess == "/dashboard")
        #expect(redirect.onFailure == "/error")
    }

    @Test("Redirect with only success path")
    func redirectOnlySuccess() {
        let redirect = Passage.Configuration.Views.Redirect(onSuccess: "/home")

        #expect(redirect.onSuccess == "/home")
        #expect(redirect.onFailure == nil)
    }

    // MARK: - LoginView Tests

    @Test("LoginView initialization")
    func loginViewInitialization() {
        let view = Passage.Configuration.Views.LoginView(
            style: .neobrutalism,
            theme: createTestTheme(),
            identifier: .email
        )

        #expect(view.name == "login")
        #expect(view.style == .neobrutalism)
        #expect(view.identifier == .email)
    }

    @Test("LoginView template name", arguments: [
        (Passage.Views.Style.neobrutalism, "login-neobrutalism"),
        (Passage.Views.Style.neomorphism, "login-neomorphism"),
        (Passage.Views.Style.minimalism, "login-minimalism"),
        (Passage.Views.Style.material, "login-material")
    ])
    func loginViewTemplate(style: Passage.Views.Style, expected: String) {
        let view = Passage.Configuration.Views.LoginView(
            style: style,
            theme: createTestTheme(),
            identifier: .email
        )

        #expect(view.template == expected)
    }

    @Test("LoginView with custom redirect")
    func loginViewWithRedirect() {
        let view = Passage.Configuration.Views.LoginView(
            style: .neobrutalism,
            theme: createTestTheme(),
            redirect: .init(onSuccess: "/dashboard"),
            identifier: .phone
        )

        #expect(view.redirect.onSuccess == "/dashboard")
        #expect(view.identifier == .phone)
    }

    // MARK: - RegisterView Tests

    @Test("RegisterView initialization")
    func registerViewInitialization() {
        let view = Passage.Configuration.Views.RegisterView(
            style: .minimalism,
            theme: createTestTheme(),
            identifier: .email
        )

        #expect(view.name == "register")
        #expect(view.style == .minimalism)
        #expect(view.identifier == .email)
    }

    @Test("RegisterView template name")
    func registerViewTemplate() {
        let view = Passage.Configuration.Views.RegisterView(
            style: .material,
            theme: createTestTheme(),
            identifier: .username
        )

        #expect(view.template == "register-material")
    }

    // MARK: - PasswordResetRequestView Tests

    @Test("PasswordResetRequestView initialization")
    func passwordResetRequestViewInitialization() {
        let view = Passage.Configuration.Views.PasswordResetRequestView(
            style: .neomorphism,
            theme: createTestTheme()
        )

        #expect(view.name == "password-reset-request")
        #expect(view.style == .neomorphism)
    }

    @Test("PasswordResetRequestView template name")
    func passwordResetRequestViewTemplate() {
        let view = Passage.Configuration.Views.PasswordResetRequestView(
            style: .minimalism,
            theme: createTestTheme()
        )

        #expect(view.template == "password-reset-request-minimalism")
    }

    // MARK: - PasswordResetConfirmView Tests

    @Test("PasswordResetConfirmView initialization")
    func passwordResetConfirmViewInitialization() {
        let view = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .material,
            theme: createTestTheme()
        )

        #expect(view.name == "password-reset-confirm")
        #expect(view.style == .material)
    }

    @Test("PasswordResetConfirmView template name")
    func passwordResetConfirmViewTemplate() {
        let view = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .neobrutalism,
            theme: createTestTheme()
        )

        #expect(view.template == "password-reset-confirm-neobrutalism")
    }

    // MARK: - Views Configuration Tests

    @Test("Views default configuration")
    func viewsDefault() {
        let views = Passage.Configuration.Views()

        #expect(views.register == nil)
        #expect(views.login == nil)
        #expect(views.passwordResetRequest == nil)
        #expect(views.passwordResetConfirm == nil)
        #expect(views.enabled == false)
    }

    @Test("Views with login view enabled")
    func viewsWithLogin() {
        let views = Passage.Configuration.Views(
            login: .init(style: .minimalism, theme: createTestTheme(), identifier: .email)
        )

        #expect(views.login != nil)
        #expect(views.enabled == true)
    }

    @Test("Views with register view enabled")
    func viewsWithRegister() {
        let views = Passage.Configuration.Views(
            register: .init(style: .material, theme: createTestTheme(), identifier: .email)
        )

        #expect(views.register != nil)
        #expect(views.enabled == true)
    }

    @Test("Views with password reset views enabled")
    func viewsWithPasswordReset() {
        let views = Passage.Configuration.Views(
            passwordResetRequest: .init(style: .neobrutalism, theme: createTestTheme()),
            passwordResetConfirm: .init(style: .neobrutalism, theme: createTestTheme())
        )

        #expect(views.passwordResetRequest != nil)
        #expect(views.passwordResetConfirm != nil)
        #expect(views.enabled == true)
    }

    @Test("Views with all views enabled")
    func viewsWithAllEnabled() {
        let theme = createTestTheme()
        let views = Passage.Configuration.Views(
            register: .init(style: .minimalism, theme: theme, identifier: .email),
            login: .init(style: .minimalism, theme: theme, identifier: .email),
            passwordResetRequest: .init(style: .minimalism, theme: theme),
            passwordResetConfirm: .init(style: .minimalism, theme: theme)
        )

        #expect(views.register != nil)
        #expect(views.login != nil)
        #expect(views.passwordResetRequest != nil)
        #expect(views.passwordResetConfirm != nil)
        #expect(views.enabled == true)
    }

    @Test("Views enabled property")
    func viewsEnabledProperty() {
        let disabledViews = Passage.Configuration.Views()
        #expect(disabledViews.enabled == false)

        let enabledViews = Passage.Configuration.Views(
            login: .init(style: .material, theme: createTestTheme(), identifier: .email)
        )
        #expect(enabledViews.enabled == true)
    }

    @Test("Views Sendable conformance")
    func viewsSendableConformance() {
        let views: Passage.Configuration.Views = .init()

        let _: any Sendable = views

        let loginView = Passage.Configuration.Views.LoginView(
            style: .neobrutalism,
            theme: createTestTheme(),
            identifier: .email
        )
        let _: any Sendable = loginView
    }

    // MARK: - PasskeyAuthenticateView Tests

    @Test("PasskeyAuthenticateView initialization")
    func passkeyAuthenticateViewInitialization() {
        let view = Passage.Configuration.Views.PasskeyAuthenticateView(
            style: .minimalism,
            theme: createTestTheme()
        )
        #expect(view.name == "passkey-authenticate")
        #expect(view.style == .minimalism)
        #expect(view.redirect.onSuccess == nil)
    }

    @Test("PasskeyAuthenticateView template name", arguments: [
        (Passage.Views.Style.minimalism, "passkey-authenticate-minimalism"),
        (Passage.Views.Style.material, "passkey-authenticate-material"),
        (Passage.Views.Style.neobrutalism, "passkey-authenticate-neobrutalism"),
        (Passage.Views.Style.neomorphism, "passkey-authenticate-neomorphism"),
    ])
    func passkeyAuthenticateViewTemplate(style: Passage.Views.Style, expected: String) {
        let view = Passage.Configuration.Views.PasskeyAuthenticateView(
            style: style,
            theme: createTestTheme()
        )
        #expect(view.template == expected)
    }

    @Test("PasskeyAuthenticateView with custom redirect")
    func passkeyAuthenticateViewWithRedirect() {
        let view = Passage.Configuration.Views.PasskeyAuthenticateView(
            style: .minimalism,
            theme: createTestTheme(),
            redirect: .init(onSuccess: "/dashboard")
        )
        #expect(view.redirect.onSuccess == "/dashboard")
    }

    @Test("Views with passkeyAuthenticate enabled")
    func viewsWithPasskeyAuthenticate() {
        let views = Passage.Configuration.Views(
            passkeyAuthenticate: .init(style: .minimalism, theme: createTestTheme())
        )
        #expect(views.passkeyAuthenticate != nil)
        #expect(views.enabled == true)
    }

    @Test("Views without passkeyAuthenticate is disabled (when nothing else is set)")
    func viewsWithoutPasskeyAuthenticateDefaultNil() {
        let views = Passage.Configuration.Views()
        #expect(views.passkeyAuthenticate == nil)
    }

    @Test("PasskeyAuthenticateView Sendable conformance")
    func passkeyAuthenticateViewSendable() {
        let _: any Sendable = Passage.Configuration.Views.PasskeyAuthenticateView(
            style: .minimalism,
            theme: createTestTheme()
        )
        #expect(Bool(true))
    }
}

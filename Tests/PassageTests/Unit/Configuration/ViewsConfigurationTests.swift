import Testing
import Foundation
@testable import Passage

@Suite
struct `Views Configuration Tests` {

    // MARK: - Test Helpers

    private func createTestTheme() -> Passage.Views.Theme {
        return Passage.Views.Theme(colors: .defaultLight)
    }

    // MARK: - Redirect Configuration Tests

    @Test
    func `Redirect default configuration`() {
        let redirect = Passage.Configuration.Views.Redirect()

        #expect(redirect.onSuccess == nil)
        #expect(redirect.onFailure == nil)
    }

    @Test
    func `Redirect with success and failure paths`() {
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: "/dashboard",
            onFailure: "/error"
        )

        #expect(redirect.onSuccess == "/dashboard")
        #expect(redirect.onFailure == "/error")
    }

    @Test
    func `Redirect with only success path`() {
        let redirect = Passage.Configuration.Views.Redirect(onSuccess: "/home")

        #expect(redirect.onSuccess == "/home")
        #expect(redirect.onFailure == nil)
    }

    // MARK: - LoginView Tests

    @Test
    func `LoginView initialization`() {
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

    @Test
    func `LoginView with custom redirect`() {
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

    @Test
    func `RegisterView initialization`() {
        let view = Passage.Configuration.Views.RegisterView(
            style: .minimalism,
            theme: createTestTheme(),
            identifier: .email
        )

        #expect(view.name == "register")
        #expect(view.style == .minimalism)
        #expect(view.identifier == .email)
    }

    @Test
    func `RegisterView template name`() {
        let view = Passage.Configuration.Views.RegisterView(
            style: .material,
            theme: createTestTheme(),
            identifier: .username
        )

        #expect(view.template == "register-material")
    }

    // MARK: - PasswordResetRequestView Tests

    @Test
    func `PasswordResetRequestView initialization`() {
        let view = Passage.Configuration.Views.PasswordResetRequestView(
            style: .neomorphism,
            theme: createTestTheme()
        )

        #expect(view.name == "password-reset-request")
        #expect(view.style == .neomorphism)
    }

    @Test
    func `PasswordResetRequestView template name`() {
        let view = Passage.Configuration.Views.PasswordResetRequestView(
            style: .minimalism,
            theme: createTestTheme()
        )

        #expect(view.template == "password-reset-request-minimalism")
    }

    // MARK: - PasswordResetConfirmView Tests

    @Test
    func `PasswordResetConfirmView initialization`() {
        let view = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .material,
            theme: createTestTheme()
        )

        #expect(view.name == "password-reset-confirm")
        #expect(view.style == .material)
    }

    @Test
    func `PasswordResetConfirmView template name`() {
        let view = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .neobrutalism,
            theme: createTestTheme()
        )

        #expect(view.template == "password-reset-confirm-neobrutalism")
    }

    // MARK: - Views Configuration Tests

    @Test
    func `Views default configuration`() {
        let views = Passage.Configuration.Views()

        #expect(views.register == nil)
        #expect(views.login == nil)
        #expect(views.passwordResetRequest == nil)
        #expect(views.passwordResetConfirm == nil)
        #expect(views.enabled == false)
    }

    @Test
    func `Views with login view enabled`() {
        let views = Passage.Configuration.Views(
            login: .init(style: .minimalism, theme: createTestTheme(), identifier: .email)
        )

        #expect(views.login != nil)
        #expect(views.enabled == true)
    }

    @Test
    func `Views with register view enabled`() {
        let views = Passage.Configuration.Views(
            register: .init(style: .material, theme: createTestTheme(), identifier: .email)
        )

        #expect(views.register != nil)
        #expect(views.enabled == true)
    }

    @Test
    func `Views with password reset views enabled`() {
        let views = Passage.Configuration.Views(
            passwordResetRequest: .init(style: .neobrutalism, theme: createTestTheme()),
            passwordResetConfirm: .init(style: .neobrutalism, theme: createTestTheme())
        )

        #expect(views.passwordResetRequest != nil)
        #expect(views.passwordResetConfirm != nil)
        #expect(views.enabled == true)
    }

    @Test
    func `Views with all views enabled`() {
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

    @Test
    func `Views enabled property`() {
        let disabledViews = Passage.Configuration.Views()
        #expect(disabledViews.enabled == false)

        let enabledViews = Passage.Configuration.Views(
            login: .init(style: .material, theme: createTestTheme(), identifier: .email)
        )
        #expect(enabledViews.enabled == true)
    }

    @Test
    func `Views Sendable conformance`() {
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

    @Test
    func `PasskeyAuthenticateView initialization`() {
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

    @Test
    func `PasskeyAuthenticateView with custom redirect`() {
        let view = Passage.Configuration.Views.PasskeyAuthenticateView(
            style: .minimalism,
            theme: createTestTheme(),
            redirect: .init(onSuccess: "/dashboard")
        )
        #expect(view.redirect.onSuccess == "/dashboard")
    }

    @Test
    func `Views with passkeyAuthenticate enabled`() {
        let views = Passage.Configuration.Views(
            passkeyAuthenticate: .init(style: .minimalism, theme: createTestTheme())
        )
        #expect(views.passkeyAuthenticate != nil)
        #expect(views.enabled == true)
    }

    @Test
    func `Views without passkeyAuthenticate is disabled (when nothing else is set)`() {
        let views = Passage.Configuration.Views()
        #expect(views.passkeyAuthenticate == nil)
    }

    @Test
    func `PasskeyAuthenticateView Sendable conformance`() {
        let _: any Sendable = Passage.Configuration.Views.PasskeyAuthenticateView(
            style: .minimalism,
            theme: createTestTheme()
        )
        #expect(Bool(true))
    }
}

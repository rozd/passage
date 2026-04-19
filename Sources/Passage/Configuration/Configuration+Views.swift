import Vapor

// MARK: - Views Configuration

public extension Passage.Configuration {

    struct Views: Sendable {
        let register: RegisterView?
        let login: LoginView?
        let passwordResetRequest: PasswordResetRequestView?
        let passwordResetConfirm: PasswordResetConfirmView?
        let magicLinkRequest: MagicLinkRequestView?
        let magicLinkVerify: MagicLinkVerifyView?
        let linkAccountSelect: LinkAccountSelectView?
        let linkAccountVerify: LinkAccountVerifyView?
        let passkeySignup: PasskeySignupView?
        let passkeyAuthenticate: PasskeyAuthenticateView?

        public init(
            register: RegisterView? = nil,
            login: LoginView? = nil,
            passwordResetRequest: PasswordResetRequestView? = nil,
            passwordResetConfirm: PasswordResetConfirmView? = nil,
            magicLinkRequest: MagicLinkRequestView? = nil,
            magicLinkVerify: MagicLinkVerifyView? = nil,
            linkAccountSelect: LinkAccountSelectView? = nil,
            linkAccountVerify: LinkAccountVerifyView? = nil,
            passkeySignup: PasskeySignupView? = nil,
            passkeyAuthenticate: PasskeyAuthenticateView? = nil,
        ) {
            self.register = register
            self.login = login
            self.passwordResetRequest = passwordResetRequest
            self.passwordResetConfirm = passwordResetConfirm
            self.magicLinkRequest = magicLinkRequest
            self.magicLinkVerify = magicLinkVerify
            self.linkAccountSelect = linkAccountSelect
            self.linkAccountVerify = linkAccountVerify
            self.passkeySignup = passkeySignup
            self.passkeyAuthenticate = passkeyAuthenticate
        }
    }
}

// MARK: Views Extension

extension Passage.Configuration.Views {

    var enabled: Bool {
        return login != nil ||
        register != nil ||
        passwordResetRequest != nil ||
        passwordResetConfirm != nil ||
        magicLinkRequest != nil ||
        magicLinkVerify != nil ||
        linkAccountSelect != nil ||
        linkAccountVerify != nil ||
        passkeySignup != nil ||
        passkeyAuthenticate != nil
    }
}

// MARK: - View Protocol

extension Passage.Configuration.Views {

    protocol View: Sendable {
        var name: String { get }
        var style: Passage.Views.Style { get }
        var theme: Passage.Views.Theme { get }
        var redirect: Redirect { get }
    }
}

// MARK: View Template Extension

extension Passage.Configuration.Views.View {

    var template: String {
        return "\(name)-\(style.templateSuffix)"
    }
}

//

public extension Passage.Configuration.Views {

    struct Redirect: Sendable {
        let onSuccess: String?
        let onFailure: String?

        public init(
            onSuccess: String? = nil,
            onFailure: String? = nil,
        ) {
            self.onSuccess = onSuccess
            self.onFailure = onFailure
        }
    }
}

// MARK: - Register View

public extension Passage.Configuration.Views {

    struct RegisterView: Sendable, View {
        let name: String = "register"
        let style: Passage.Views.Style
        let theme: Passage.Views.Theme
        let redirect: Redirect
        let identifier: Identifier.Kind

        public init(
            style: Passage.Views.Style,
            theme: Passage.Views.Theme,
            redirect: Redirect = .init(),
            identifier: Identifier.Kind,
        ) {
            self.style = style
            self.theme = theme
            self.redirect = redirect
            self.identifier = identifier
        }
    }

}

// MARK: - Login View

public extension Passage.Configuration.Views {

    struct LoginView: Sendable, View {
        let name: String = "login"
        let style: Passage.Views.Style
        let theme: Passage.Views.Theme
        let redirect: Redirect
        let identifier: Identifier.Kind

        public init(
            style: Passage.Views.Style,
            theme: Passage.Views.Theme,
            redirect: Redirect = .init(),
            identifier: Identifier.Kind,
        ) {
            self.style = style
            self.theme = theme
            self.redirect = redirect
            self.identifier = identifier
        }
    }

}

// MARK: - Password Reset View

public extension Passage.Configuration.Views {

    struct PasswordResetRequestView: Sendable, View {
        let name: String = "password-reset-request"
        let style: Passage.Views.Style
        let theme: Passage.Views.Theme
        let redirect: Redirect

        public init(
            style: Passage.Views.Style,
            theme: Passage.Views.Theme,
            redirect: Redirect = .init(),
        ) {
            self.style = style
            self.theme = theme
            self.redirect = redirect
        }
    }

    struct PasswordResetConfirmView: Sendable, View {
        let name: String = "password-reset-confirm"
        let style: Passage.Views.Style
        let theme: Passage.Views.Theme
        let redirect: Redirect

        public init(
            style: Passage.Views.Style,
            theme: Passage.Views.Theme,
            redirect: Redirect = .init(),
        ) {
            self.style = style
            self.theme = theme
            self.redirect = redirect
        }
    }

}

// MARK: - Magic Link Views

public extension Passage.Configuration.Views {

    struct MagicLinkRequestView: Sendable, View {
        let name: String = "magic-link-request"
        let style: Passage.Views.Style
        let theme: Passage.Views.Theme
        let redirect: Redirect

        public init(
            style: Passage.Views.Style,
            theme: Passage.Views.Theme,
            redirect: Redirect = .init()
        ) {
            self.style = style
            self.theme = theme
            self.redirect = redirect
        }
    }

    struct MagicLinkVerifyView: Sendable, View {
        let name: String = "magic-link-verify"
        let style: Passage.Views.Style
        let theme: Passage.Views.Theme
        let redirect: Redirect

        public init(
            style: Passage.Views.Style,
            theme: Passage.Views.Theme,
            redirect: Redirect
        ) {
            self.style = style
            self.theme = theme
            self.redirect = redirect
        }
    }

}

// MARK: - OAuth Link Views

public extension Passage.Configuration.Views {

    struct LinkAccountSelectView: Sendable, View {
        let name: String = "link-account-select"
        let style: Passage.Views.Style
        let theme: Passage.Views.Theme
        let redirect: Redirect

        public init(
            style: Passage.Views.Style,
            theme: Passage.Views.Theme,
            redirect: Redirect = .init()
        ) {
            self.style = style
            self.theme = theme
            self.redirect = redirect
        }
    }

    struct LinkAccountVerifyView: Sendable, View {
        let name: String = "link-account-verify"
        let style: Passage.Views.Style
        let theme: Passage.Views.Theme
        let redirect: Redirect

        public init(
            style: Passage.Views.Style,
            theme: Passage.Views.Theme,
            redirect: Redirect = .init()
        ) {
            self.style = style
            self.theme = theme
            self.redirect = redirect
        }
    }

}

// MARK: - Passkey Views

public extension Passage.Configuration.Views {

    struct PasskeySignupView: Sendable, View {
        let name: String = "passkey-signup"
        let style: Passage.Views.Style
        let theme: Passage.Views.Theme
        let redirect: Redirect
        let identifier: Identifier.Kind

        public init(
            style: Passage.Views.Style,
            theme: Passage.Views.Theme,
            redirect: Redirect = .init(),
            identifier: Identifier.Kind,
        ) {
            self.style = style
            self.theme = theme
            self.redirect = redirect
            self.identifier = identifier
        }
    }

    struct PasskeyAuthenticateView: Sendable, View {
        let name: String = "passkey-authenticate"
        let style: Passage.Views.Style
        let theme: Passage.Views.Theme
        let redirect: Redirect

        public init(
            style: Passage.Views.Style,
            theme: Passage.Views.Theme,
            redirect: Redirect = .init(),
        ) {
            self.style = style
            self.theme = theme
            self.redirect = redirect
        }
    }

}


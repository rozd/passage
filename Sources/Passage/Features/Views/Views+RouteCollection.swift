import Vapor

extension Passage.Views {

    struct RouteCollection: Vapor.RouteCollection, Sendable {

        let group: [PathComponent]
        let config: Passage.Configuration.Views
        let routes: Passage.Configuration.Routes
        let restoration: Passage.Configuration.Restoration
        let passwordless: Passage.Configuration.Passwordless
        let federatedLogin: Passage.Configuration.FederatedLogin
        let passkey: Passage.Configuration.Passkey?

        func boot(routes builder: any RoutesBuilder) throws {
            let grouped = group.isEmpty ? builder : builder.grouped(group)

            if let _ = config.register {
                grouped.get(routes.register.path) { req in
                    try await req.views.renderRegisterView()
                }
            }

            if let _ = config.login {
                grouped.get(routes.login.path) { req in
                    try await req.views.renderLoginView()
                }
            }

            if let _ = config.passwordResetRequest {
                grouped.get(restoration.email.routes.request.path) { req in
                    try await req.views.renderResetPasswordRequestView(
                        for: .email
                    )
                }
                grouped.get(restoration.phone.routes.request.path) { req in
                    try await req.views.renderResetPasswordRequestView(
                        for: .phone
                    )
                }
            }

            if let _ = config.passwordResetConfirm {
                grouped.get(restoration.email.routes.verify.path) { req in
                    try await req.views.renderResetPasswordConfirmView(
                        for: .email
                    )
                }
                grouped.get(restoration.phone.routes.verify.path) { req in
                    try await req.views.renderResetPasswordConfirmView(
                        for: .phone
                    )
                }
            }

            if let _ = config.magicLinkRequest, let emailMagicLink = passwordless.emailMagicLink {
                grouped.get(emailMagicLink.routes.request.path) { req in
                    try await req.views.renderMagicLinkRequestView()
                }
            }

            // MARK: Account Linking Views

            // Select account to link
            if let _ = config.linkAccountSelect {
                grouped.get(federatedLogin.linkAccountSelectPath) { req in
                    try await req.views.renderLinkAccountSelectView()
                }
            }

            // Verify account to link
            if let _ = config.linkAccountVerify {
                grouped.get(federatedLogin.linkAccountVerifyPath) { req in
                    try await req.views.renderLinkAccountVerifyView()
                }
            }

            if let routes = passkey?.routes {
                grouped.group(routes.group) { group in
                    if config.passkeySignup != nil, let route = routes.guestRegistrationBegin {
                        group.get(route.path) { req in
                            try await req.views.renderPasskeySignupView()
                        }
                    }
                    if config.passkeyAuthenticate != nil {
                        group.get(routes.authenticationBegin.path) { req in
                            try await req.views.renderPasskeyAuthenticateView()
                        }
                    }
                }
            }
        }

    }

}

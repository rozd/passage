import Vapor

// MARK: - Guest Registration View Params

extension Passage.Views {

    func renderPasskeyGuestRegistrationView() async throws -> View {
        guard let view = config.passkeyGuestRegistration else {
            throw Abort(.notFound)
        }
        let params = try request.query.decode(PasskeyGuestRegistrationViewParams.self)

        let group = request.configuration.routes.group

        let beginURL = request.configuration.passkey.routes.guestRegistrationBeginPath.map {
            "/" + (group + $0).string
        }

        let finishURL = request.configuration.passkey.routes.guestRegistrationFinishPath.map {
            "/" + (group + $0).string
        }

        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params.copyWith(
                    byEmail: view.identifier == .email,
                    byPhone: view.identifier == .phone,
                    byUsername: view.identifier == .username,
                    signupBeginURL: beginURL,
                    signupFinishURL: finishURL,
                ),
            ),
        )
    }

    func handlePasskeyGuestRegistrationFormSuccess(
        of view: Passage.Configuration.Views.PasskeyGuestRegistrationView,
        at path: [PathComponent],
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withSuccessMessage: "Starting passkey signup — JavaScript is required to complete.",
        )
    }

    func handlePasskeyGuestRegistrationFormFailure(
        of view: Passage.Configuration.Views.PasskeyGuestRegistrationView,
        at path: [PathComponent],
        with error: any Error,
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withError: error,
            withDefaultMessage: "An unknown error occurred during passkey signup.",
        )
    }
}

// MARK: Guest Registration View Params

extension Passage.Views {

    struct PasskeyGuestRegistrationViewParams: Content {
        let byEmail: Bool
        let byPhone: Bool
        let byUsername: Bool
        let error: String?
        let success: String?
        let signupBeginURL: String?
        let signupFinishURL: String?

        func copyWith(
            byEmail: Bool? = nil,
            byPhone: Bool? = nil,
            byUsername: Bool? = nil,
            error: String? = nil,
            success: String? = nil,
            signupBeginURL: String? = nil,
            signupFinishURL: String? = nil,
        ) -> Self {
            .init(
                byEmail: byEmail ?? self.byEmail,
                byPhone: byPhone ?? self.byPhone,
                byUsername: byUsername ?? self.byUsername,
                error: error ?? self.error,
                success: success ?? self.success,
                signupBeginURL: signupBeginURL ?? self.signupBeginURL,
                signupFinishURL: signupFinishURL ?? self.signupFinishURL,
            )
        }
    }

}

// MARK: - Authentication View Params

extension Passage.Views {

    func renderPasskeyAuthenticationView() async throws -> View {
        guard let view = config.passkeyAuthentication else {
            throw Abort(.notFound)
        }
        let params = try request.query.decode(PasskeyAuthenticationViewParams.self)

        let group = request.configuration.routes.group
        let beginURL = "/" + (group + request.configuration.passkey.routes.authenticationBeginPath).string
        let finishURL = "/" + (group + request.configuration.passkey.routes.authenticationFinishPath).string

        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params.copyWith(
                    authenticateBeginURL: beginURL,
                    authenticateFinishURL: finishURL,
                    redirectOnSuccess: view.redirect.onSuccess,
                ),
            ),
        )
    }

}

// MARK: Authentication View Params

extension Passage.Views {

    struct PasskeyAuthenticationViewParams: Content {
        let error: String?
        let success: String?
        let authenticateBeginURL: String?
        let authenticateFinishURL: String?
        let redirectOnSuccess: String?

        func copyWith(
            error: String? = nil,
            success: String? = nil,
            authenticateBeginURL: String? = nil,
            authenticateFinishURL: String? = nil,
            redirectOnSuccess: String? = nil,
        ) -> Self {
            .init(
                error: error ?? self.error,
                success: success ?? self.success,
                authenticateBeginURL: authenticateBeginURL ?? self.authenticateBeginURL,
                authenticateFinishURL: authenticateFinishURL ?? self.authenticateFinishURL,
                redirectOnSuccess: redirectOnSuccess ?? self.redirectOnSuccess,
            )
        }
    }

}

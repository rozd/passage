import Vapor

// MARK: - Signup View Params

extension Passage.Views {

    func renderPasskeySignupView() async throws -> View {
        guard let view = config.passkeySignup else {
            throw Abort(.notFound)
        }
        let params = try request.query.decode(PasskeySignupViewParams.self)

        let group = request.configuration.routes.group

        let beginURL = request.configuration.passkey.routes.signupBeginPath.map {
            "/" + (group + $0).string
        }

        let finishURL = request.configuration.passkey.routes.signupFinishPath.map {
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

    func handlePasskeySignupFormSuccess(
        of view: Passage.Configuration.Views.PasskeySignupView,
        at path: [PathComponent],
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withSuccessMessage: "Starting passkey signup — JavaScript is required to complete.",
        )
    }

    func handlePasskeySignupFormFailure(
        of view: Passage.Configuration.Views.PasskeySignupView,
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

// MARK: Signup View Params

extension Passage.Views {

    struct PasskeySignupViewParams: Content {
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

// MARK: - Authenticate View Params

extension Passage.Views {

    func renderPasskeyAuthenticateView() async throws -> View {
        guard let view = config.passkeyAuthenticate else {
            throw Abort(.notFound)
        }
        let params = try request.query.decode(PasskeyAuthenticateViewParams.self)

        let group = request.configuration.routes.group
        let beginURL = "/" + (group + request.configuration.passkey.routes.authenticateBeginPath).string
        let finishURL = "/" + (group + request.configuration.passkey.routes.authenticateFinishPath).string

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

// MARK: Authenticate View Params

extension Passage.Views {

    struct PasskeyAuthenticateViewParams: Content {
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

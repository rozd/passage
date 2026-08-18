import Vapor
import Leaf
import LeafKit

// MARK: - Views Namespace

public extension Passage {

    struct Views: Sendable {
        let request: Request
        let config: Configuration.Views
    }

}

extension Passage.Views {

    static func registerLeafTempleates(
        on app: Application
    ) throws {
        guard let resourcePath = Bundle.module.resourcePath else {
            throw PassageError.unexpected(message: "Could not locate resource path for Passage module.")
        }
        let sources = app.leaf.sources
        try sources.register(
            source: "passage",
            using: NIOLeafFiles(
                fileio: app.fileio,
                limits: [.toSandbox, .requireExtensions],
                sandboxDirectory: "\(resourcePath)/Views",
                viewDirectory: "\(resourcePath)/Views"
            )
        )
        app.leaf.sources = sources
    }

}

extension Request {

    var views: Passage.Views {
        .init(request: self, config: configuration.views)
    }

}

// MARK: - Login View Implementation

extension Passage.Views {

    func renderLoginView() async throws -> View {
        guard let view = config.login else {
            throw Abort(.notFound)
        }
        let params = try request.query.decode(LoginViewParams.self)

        // Check if magic link is enabled (requires both passwordless backend AND views config)
        let magicLinkEnabled = request.configuration.passwordless.emailMagicLink != nil &&
                              config.magicLinkRequest != nil

        let magicLinkPath = magicLinkEnabled
            ? request.configuration.passwordless.emailMagicLink?.routes.request.path
            : nil

        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params.copyWith(
                    byEmail: view.identifier == .email,
                    byPhone: view.identifier == .phone,
                    byUsername: view.identifier == .username,
                    withGoogle: true,
                    registerLink: "/test",
                    resetPasswordLink: "/test",
                    byEmailMagicLink: magicLinkEnabled,
                    magicLinkRequestLink: magicLinkPath.map { "/\($0.string)" }
                ),
            ),
        )
    }

    func handleLoginFormSuccess(
        of view: Passage.Configuration.Views.LoginView,
        at path: [PathComponent],
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withSuccessMessage: "You have successfully logged in.",
        )
    }

    func handleLoginFormFailure(
        of view: Passage.Configuration.Views.LoginView,
        at path: [PathComponent],
        with error: any Error,
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withError: error,
            withDefaultMessage: "An unknown error occurred during login.",
        )
    }
}

// MARK: - Register View Implementation

extension Passage.Views {

    func renderRegisterView() async throws -> View {
        guard let view = config.register else {
            throw Abort(.notFound)
        }
        let params = try request.query.decode(RegisterViewParams.self)
        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params.copyWith(
                    byEmail: view.identifier == .email,
                    byPhone: view.identifier == .phone,
                    byUsername: view.identifier == .username,
                    loginLink: "/test"
                ),
            ),
        )
    }

    func handleRegisterFormSuccess(
        of view: Passage.Configuration.Views.RegisterView,
        at path: [PathComponent],
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withSuccessMessage: "You have successfully registered.",
        )
    }

    func handleRegisterFormFailure(
        of view: Passage.Configuration.Views.RegisterView,
        at path: [PathComponent],
        with error: any Error,
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withError: error,
            withDefaultMessage: "An unknown error occurred during registration.",
        )
    }

}

// MARK: - Password Reset Request View Implementation

extension Passage.Views {

    func renderResetPasswordRequestView(
        for identifier: Identifier.Kind
    ) async throws -> View {
        guard let view = config.passwordResetRequest else {
            throw Abort(.notFound)
        }
        let params = try request.query.decode(ResetPasswordRequestViewParams.self)
        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params.copyWith(
                    byEmail: identifier == .email,
                    byPhone: identifier == .phone,
                ),
            ),
        )
    }

    func handleResetPasswordRequestFormSuccess(
        of view: Passage.Configuration.Views.PasswordResetRequestView,
        at path: [PathComponent],
    ) -> Response {
        return request.redirect(
            to: buildRedirectLocation(
                for: path,
                success: "If an account with that identifier exists, a password reset link has been sent."
            )
        )
    }

    func handleResetPasswordRequestFormFailure(
        of view: Passage.Configuration.Views.PasswordResetRequestView,
        at path: [PathComponent],
        with error: any Error,
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withError: error,
            withDefaultMessage: "An unknown error occurred during password reset request.",
        )
    }

}

// MARK: - Password Reset Confirm View Implementation

extension Passage.Views {

    func renderResetPasswordConfirmView(
        for identifier: Identifier.Kind
    ) async throws -> View {
        guard let view = config.passwordResetConfirm else {
            throw Abort(.notFound)
        }
        let params = try request.query.decode(ResetPasswordConfirmViewParams.self)
        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params.copyWith(
                    byEmail: identifier == .email,
                    byPhone: identifier == .phone,
                ),
            ),
        )
    }

    func handleResetPasswordConfirmFormSuccess(
        of view: Passage.Configuration.Views.PasswordResetConfirmView,
        at path: [PathComponent],
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withSuccessMessage: "Your password has been successfully reset.",
        )
    }

    func handleResetPasswordConfirmFormFailure(
        of view: Passage.Configuration.Views.PasswordResetConfirmView,
        at path: [PathComponent],
        with error: any Error,
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withError: error,
            withDefaultMessage: "An unknown error occurred during password reset.",
        )
    }

}

// MARK: - Magic Link Request View Implementation

extension Passage.Views {

    func renderMagicLinkRequestView() async throws -> View {
        guard let view = config.magicLinkRequest else {
            throw Abort(.notFound)
        }
        let params = try request.query.decode(MagicLinkRequestViewParams.self)
        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params.copyWith(
                    byEmail: true
                )
            )
        )
    }

    func handleMagicLinkRequestSuccess(
        of view: Passage.Configuration.Views.MagicLinkRequestView,
        at path: [PathComponent],
        email: String
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withParams: ["identifier": email],
            withSuccessMessage: "A sign-in link has been sent to \(email)"
        )
    }

    func handleMagicLinkRequestFailure(
        of view: Passage.Configuration.Views.MagicLinkRequestView,
        at path: [PathComponent],
        with error: any Error
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withError: error,
            withDefaultMessage: "Failed to send magic link. Please try again."
        )
    }

}

// MARK: - Magic Link Verify View Implementation

extension Passage.Views {

    func renderMagicLinkVerifySuccess(
        of view: Passage.Configuration.Views.MagicLinkVerifyView,
        at path: [PathComponent],
    ) async throws -> View {
        guard let view = config.magicLinkVerify else {
            throw Abort(.notFound)
        }
        let params = try request.query.decode(MagicLinkVerifyViewParams.self)
        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params.copyWith(
                    success: "You have successfully signed in with your magic link.",
                    redirectUrl: view.redirect.onSuccess,
                )
            )
        )
    }

    func renderMagicLinkVerifyFailure(
        of view: Passage.Configuration.Views.MagicLinkVerifyView,
        at path: [PathComponent],
        with error: any Error,
        loginPath: [PathComponent]
    ) async throws -> View {
        guard let view = config.magicLinkVerify else {
            throw Abort(.notFound)
        }
        let errorMessage: String
        switch error {
        case let error as ValidationsError:
            errorMessage = "Validation error: \(error.description)"
            break
        case let error as any AbortError:
            errorMessage = error.reason
            break
        default:
            errorMessage = "Failed to verify magic link. Please try again."
            break
        }
        let params = try request.query.decode(MagicLinkVerifyViewParams.self)
        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params.copyWith(
                    error: errorMessage,
                    loginLink: "/\(loginPath.string)",
                )
            )
        )
    }

}

// MARK: - Account Link Select View Implementation

extension Passage.Views {

    func renderLinkAccountSelectView() async throws -> View {
        guard let view = config.linkAccountSelect else {
            throw Abort(.notFound)
        }
        let state = try await request.linking.manual.loadLinkingState()
        let params = LinkAccountSelectViewParams(
            provider: state.provider.description,
            candidates: state.candidates.map {
                .init(
                    userId: $0.userId,
                    maskedEmail: $0.email.map { maskEmail($0) },
                    maskedPhone: $0.phone.map { maskPhone($0) }
                )
            },
            error: nil
        )
        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params
            )
        )
    }

    func handleLinkAccountSelectFormSubmit(
        of view: Passage.Configuration.Views.LinkAccountSelectView,
        at path: [PathComponent],
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withSuccessMessage: nil,
        )
    }

    func handleLinkAccountSelectFormFailure(
        of view: Passage.Configuration.Views.LinkAccountSelectView,
        at path: [PathComponent],
        with error: any Error,
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withError: error,
            withDefaultMessage: "An unknown error occurred during password reset request.",
        )
    }
}

// MARK: - Account Link Verify View Implementation

extension Passage.Views {

    func renderLinkAccountVerifyView() async throws -> View {
        guard let view = config.linkAccountVerify else {
            throw Abort(.notFound)
        }

        let state = try await request.linking.manual.loadLinkingState()

        guard let selectedUserId = state.selectedUserId else {
            throw Abort(.badRequest, reason: "No user selected")
        }

        guard let candidate = state.candidates.first(where: { $0.userId == selectedUserId }) else {
            throw Abort(.badRequest, reason: "Invalid user selection")
        }

        let params = LinkAccountVerifyViewParams(
            maskedEmail: candidate.email.map { maskEmail($0) },
            hasPassword: candidate.hasPassword,
            canUseEmailCode: !candidate.hasPassword && candidate.isEmailVerified,
            error: nil
        )

        return try await request.view.render(
            view.template,
            Context(
                theme: view.theme.resolve(for: .light),
                params: params
            )
        )
    }

    func handleLinkAccountVerifyFormSubmit(
        of view: Passage.Configuration.Views.LinkAccountVerifyView,
        at path: [PathComponent],
    ) -> Response {
        return request.redirect(to: request.configuration.federatedLogin.redirectLocation)
    }

    func handleLinkAccountVerifyFormFailure(
        of view: Passage.Configuration.Views.LinkAccountVerifyView,
        at path: [PathComponent],
        with error: any Error,
    ) -> Response {
        return redirect(
            view: view,
            at: path,
            withError: error,
            withDefaultMessage: "An unknown error occurred during account linking.",
        )
    }
}

// MARK: - Masking Helpers

extension Passage.Views {

    func maskEmail(_ email: String) -> String {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return email }
        let local = String(parts[0])
        let domain = String(parts[1])
        let masked = local.prefix(1) + "***"
        return "\(masked)@\(domain)"
    }

    func maskPhone(_ phone: String) -> String {
        guard phone.count > 4 else { return "***" }
        return "***" + phone.suffix(4)
    }

}

// MARK: - Redirect Helpers

extension Passage.Views {

    func redirect(
        view: any Passage.Configuration.Views.View,
        at path: [PathComponent],
        withParams params: [String: String?] = [:],
        withSuccessMessage success: String?,
    ) -> Response {
        guard let location = view.redirect.onSuccess else {
            return request.redirect(
                to: buildRedirectLocation(
                    for: path,
                    params: params,
                    success: success,
                )
            )
        }
        return request.redirect(to: location)
    }

    func redirect(
        view: any Passage.Configuration.Views.View,
        at path: [PathComponent],
        withParams params: [String: String?] = [:],
        withError error: any Error,
        withDefaultMessage message: String = "An unexpected error occurred. Please try again.",
    ) -> Response {
        let errorMessage: String
        switch error {
        case let error as ValidationsError:
            errorMessage = "Validation error: \(error.description)"
            break
        case let error as any AbortError:
            errorMessage = error.reason
            break
        default:
            errorMessage = message
            break
        }
        guard let location = view.redirect.onFailure else {
            return request.redirect(
                to: buildRedirectLocation(
                    for: path,
                    params: params,
                    error: errorMessage
                )
            )
        }
        return request.redirect(to: location)
    }

}

// MARK: - Redirect Location Builder

extension Passage.Views {

    func buildRedirectLocation(
        for path: [PathComponent],
        params: [String: String?] = [:],
        success: String? = nil,
        error: String? = nil,
    ) -> String {
        var components = URLComponents()
        components.path = "/\(path.string)"
        let queryItems = [
            params,
            ["success": success, "error": error],
        ].flatMap {
            $0.compactMap { key, value -> URLQueryItem? in
                guard let value else { return nil }
                return URLQueryItem(name: key, value: value)
            }
        }
        if queryItems.count > 0 {
            components.queryItems = queryItems
        }
        return components.string ?? "/"
    }
}

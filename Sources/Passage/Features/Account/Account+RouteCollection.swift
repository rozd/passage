import Vapor

extension Passage.Account {

    struct RouteCollection: Vapor.RouteCollection, Sendable {

        init(routes: Passage.Configuration.Routes) {
            self.routes = routes
        }

        let routes: Passage.Configuration.Routes

        func boot(routes builder: any RoutesBuilder) throws {
            let grouped = routes.group.isEmpty ? builder : builder.grouped(routes.group)
            grouped.post(routes.register.path, use: self.register)
            grouped
                .grouped(LoginThrottleMiddleware())
                .post(routes.login.path, use: self.login)

            grouped
                .grouped(PassageSessionAuthenticator())
                .grouped(PassageBearerAuthenticator())
                .post(routes.logout.path, use: self.logout)

            (routes.currentUser.shouldBypassGroup ? builder : grouped)
                .grouped(PassageSessionAuthenticator())
                .grouped(PassageBearerAuthenticator())
                .get(routes.currentUser.path, use: self.currentUser)
        }

    }

}

// MARK: - Register

extension Passage.Account.RouteCollection {

    fileprivate func register(_ req: Request) async throws -> Response {
        do {
            let form = try req.decodeContentAsFormOfType(req.contracts.registerForm)
            try await req.account.register(form: form)

            guard req.isFormSubmission, req.isWaitingForHTML, let view = req.configuration.views.register else {
                return try await HTTPStatus.ok.encodeResponse(for: req)
            }

            return req.views.handleRegisterFormSuccess(
                of: view,
                at: routes.group + routes.register.path,
            )

        } catch {
            guard req.isFormSubmission, req.isWaitingForHTML, let view = req.configuration.views.register else {
                throw error
            }

            return req.views.handleRegisterFormFailure(
                of: view,
                at: routes.group + routes.register.path,
                with: error
            )
        }
    }
}

// MARK: - Login

extension Passage.Account.RouteCollection {

    fileprivate func login(_ req: Request) async throws -> Response {
        do {
            let form = try req.decodeContentAsFormOfType(req.contracts.loginForm)
            let user = try await req.account.login(form: form)

            guard req.isFormSubmission, req.isWaitingForHTML, let view = req.configuration.views.login else {
                guard let authUser = try await req.passage.login(
                    user,
                    origin: .login,
                    via: .bearer,
                ) else {
                    throw Abort(.internalServerError)
                }
                return try await authUser.encodeResponse(for: req)
            }

            _ = try await req.passage.login(user, origin: .login, via: .browser)

            return req.views.handleLoginFormSuccess(
                of: view,
                at: routes.group + routes.login.path,
            )
        } catch {
            guard req.isFormSubmission, req.isWaitingForHTML, let view = req.configuration.views.login else {
                throw error
            }

            return req.views.handleLoginFormFailure(
                of: view,
                at: routes.group + routes.login.path,
                with: error
            )
        }
    }

}

// MARK: - Logout

extension Passage.Account.RouteCollection {

    fileprivate func logout(_ req: Request) async throws -> HTTPStatus {
        let _ = try req.decodeContentAsFormOfType(req.contracts.logoutForm)

        try await req.account.logout()

        return .ok
    }

}

// MARK: - Current User

extension Passage.Account.RouteCollection {

    fileprivate func currentUser(_ req: Request) async throws -> AuthUser.User {
        return try req.account.currentUser()
    }

}

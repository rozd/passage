import Foundation
import NIOFoundationCompat
import Vapor

extension Passage.Passkey {
    struct RouteCollection: Vapor.RouteCollection, Sendable {
        let routes: Passage.Configuration.Passkey.Routes
        let groupPath: [PathComponent]

        func boot(routes builder: any RoutesBuilder) throws {
            let grouped = groupPath.isEmpty ? builder : builder.grouped(groupPath)

            grouped.group(routes.group) { group in
                // Registration ceremony for new users — discoverable, public.
                // Opt-in: the routes register only when both sides are set.
                if let guestRegistrationBegin = routes.guestRegistrationBegin,
                   let guestRegistrationFinish = routes.guestRegistrationFinish {
                    group
                        .post(guestRegistrationBegin.path, use: self.beginSignup)
                    group
                        .post(guestRegistrationFinish.path, use: self.finishSignup)
                }

                // Registration ceremony – discoverable, but requires authentication to initiate and complete.
                let authed = group
                    .grouped(PassageSessionAuthenticator())
                    .grouped(PassageBearerAuthenticator())
                authed
                    .post(routes.registrationBegin.path, use: self.beginRegistration)
                authed
                    .post(routes.registrationFinish.path, use: self.finishRegistration)

                // Authentication ceremony — discoverable, public.
                group
                    .post(routes.authenticationBegin.path, use: self.beginAuthentication)
                group
                    .post(routes.authenticationFinish.path, use: self.finishAuthentication)
            }
        }
    }
}

// MARK: - Signup (public)

extension Passage.Passkey.RouteCollection {

    fileprivate func beginSignup(_ req: Request) async throws -> Response {
        guard let signupBeginPath = routes.guestRegistrationBeginPath else {
            throw Abort(.notFound)
        }
        do {
            let form = try req.decodeContentAsFormOfType(req.contracts.passkeySignupForm)
            let body = try await req.passkey.beginSignup(form: form)

            guard req.isFormSubmission, req.isWaitingForHTML, let view = req.configuration.views.passkeySignup else {
                return try await body.encodeResponse(for: req)
            }

            return req.views.handlePasskeySignupFormSuccess(
                of: view,
                at: groupPath + signupBeginPath,
            )
        } catch {
            guard req.isFormSubmission, req.isWaitingForHTML, let view = req.configuration.views.passkeySignup else {
                throw error
            }

            return req.views.handlePasskeySignupFormFailure(
                of: view,
                at: groupPath + signupBeginPath,
                with: error
            )
        }
    }

    fileprivate func finishSignup(_ req: Request) async throws -> Response {
        let maxBody = req.application.routes.defaultMaxBodySize.value
        let buffer = try await req.body.collect(upTo: maxBody)
        let rawBody = Data(buffer: buffer)
        let stored = try await req.passkey.finishSignup(rawBody: rawBody)
        let response = PasskeyRegistrationResponse(credentialID: stored.credentialID)
        return try await response.encodeResponse(status: .created, for: req)
    }

}

// MARK: - Register (authenticated)

extension Passage.Passkey.RouteCollection {

    fileprivate func beginRegistration(_ req: Request) async throws -> Response {
        let body: PasskeyRegisterRequest?
        if (req.body.data?.readableBytes ?? 0) > 0 {
            body = try req.content.decode(PasskeyRegisterRequest.self)
        } else {
            body = nil
        }

        let encodable = try await req.passkey.beginRegistration(request: body)
        return try await encodable.encodeResponse(for: req)
    }

    fileprivate func finishRegistration(_ req: Request) async throws -> Response {
        let maxBody = req.application.routes.defaultMaxBodySize.value
        let buffer = try await req.body.collect(upTo: maxBody)
        let rawBody = Data(buffer: buffer)
        let stored = try await req.passkey.finishRegistration(rawBody: rawBody)
        let response = PasskeyRegistrationResponse(credentialID: stored.credentialID)
        return try await response.encodeResponse(status: .created, for: req)
    }

}

// MARK: - Authentication

extension Passage.Passkey.RouteCollection {

    fileprivate func beginAuthentication(_ req: Request) async throws -> Response {
        let body = try await req.passkey.beginAuthentication()
        return try await body.encodeResponse(for: req)
    }

    fileprivate func finishAuthentication(_ req: Request) async throws -> Response {
        let maxBody = req.application.routes.defaultMaxBodySize.value
        let buffer = try await req.body.collect(upTo: maxBody)
        let rawBody = Data(buffer: buffer)
        let (_, code) = try await req.passkey.finishAuthentication(rawBody: rawBody)
        let response = PasskeyAuthenticationResponse(code: code)
        return try await response.encodeResponse(for: req)
    }

}

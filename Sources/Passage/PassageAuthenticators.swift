public import JWT
public import Vapor

// MARK: - Bearer Authenticator

public struct PassageBearerAuthenticator: JWTAuthenticator {
    public typealias Payload = AccessToken

    public init() {}

    public func authenticate(
        jwt: AccessToken,
        for request: Vapor.Request,
    ) async throws {
        let sessionId = jwt.sessionId
        if await request.hooks.account?.isSessionRevoked(sessionId, on: request) == true {
            throw AuthenticationError.sessionRevoked
        }
        request.storage[PassageContext.BearerSessionIdKey.self] = sessionId
        let user = try await request.account.user(for: jwt)
        request.auth.login(user)
    }

}

// MARK: - Sessions Authenticator

public struct PassageSessionAuthenticator: AsyncAuthenticator {

    public init() {}

    public func respond(
        to request: Request,
        chainingTo next: any AsyncResponder,
    ) async throws -> Response {
        guard request.configuration.sessions.enabled else {
            return try await next.respond(to: request)
        }

        // if the user has already been authenticated
        // by a previous middleware, continue
        if request.auth.has(request.store.users.userType) {
            return try await next.respond(to: request)
        }

        if request.hasSession, let aID = request.session.authenticated(request.store.users.userType) {
            if let sessionId = request.session.sessionId,
               await request.hooks.account?.isSessionRevoked(sessionId, on: request) == true {
                request.session.unauthenticate(request.store.users.userType)
                request.session.sessionId = nil
            } else {
                let user = try await request.account.user(
                    withId: aID.description
                )
                request.auth.login(user)
            }
        }

        // respond to the request
        let response = try await next.respond(to: request)
        if let user = request.auth.get(request.store.users.userType) {
            // if a user has been authed (or is still authed), store in the session
            request.session.authenticate(user)
        } else if request.hasSession {
            // if no user is authed, it's possible they've been unauthed.
            // remove from session.
            request.session.unauthenticate(request.store.users.userType)
        }
        return response
    }

}

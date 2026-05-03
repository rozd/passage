import Vapor

public struct PassageContext: Sendable {
    let request: Request

    public var user: any User {
        get throws {
            try request.auth.require(request.store.users.userType)
        }
    }

    public var hasUser: Bool {
        request.auth.has(request.store.users.userType)
    }
}

// MARK: - Vapor Authentication

extension PassageContext {

    func login(_ user: any User) {
        request.auth.login(user)
        if request.configuration.sessions.enabled {
            request.session.authenticate(user)
        }
    }

    func logout() {
        request.auth.logout(request.store.users.userType)
        if request.configuration.sessions.enabled {
            request.session.unauthenticate(request.store.users.userType)
        }
    }
}

// MARK: - Expose Passage Features

public extension PassageContext {

    var verification: Passage.Verification {
        request.verification
    }

    var passwordless: Passage.Passwordless {
        request.passwordless
    }
}


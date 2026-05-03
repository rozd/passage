public import Vapor

public extension Passage.Hooks {

    protocol Account: Sendable {

        // MARK: Registration Hooks

        func willRegister(
            with form: any RegisterForm,
            on request: Request,
        ) async throws

        func didRegister(
            user: any User,
            on request: Request,
        ) async

        // MARK: Login Hooks

        func willLogin(
            user: any User,
            on request: Request,
        ) async throws

        func didLogin(
            user: any User,
            on request: Request,
        ) async

        // MARK: Logout Hooks

        func willLogout(
            user: any User,
            on request: Request,
        ) async throws

        func didLogout(
            user: any User,
            on request: Request,
        ) async
    }

}

// MARK: - Default Implementation

public extension Passage.Hooks.Account {

    func willRegister(
        with form: any RegisterForm,
        on request: Request,
    ) async throws {}

    func didRegister(
        user: any User,
        on request: Request,
    ) async {}

    func willLogin(
        user: any User,
        on request: Request,
    ) async throws {}

    func didLogin(
        user: any User,
        on request: Request,
    ) async {}

    func willLogout(
        user: any User,
        on request: Request,
    ) async throws {}

    func didLogout(
        user: any User,
        on request: Request,
    ) async {}
}

// MARK: - Closure-Based Hooks

public struct _AccountHooksClosures: Passage.Hooks.Account {

    let _willRegister: (@Sendable (any RegisterForm, Request) async throws -> Void)?
    let _didRegister: (@Sendable (any User, Request) async -> Void)?

    let _willLogin: (@Sendable (any User, Request) async throws -> Void)?
    let _didLogin: (@Sendable (any User, Request) async -> Void)?

    let _willLogout: (@Sendable (any User, Request) async throws -> Void)?
    let _didLogout: (@Sendable (any User, Request) async -> Void)?

    public func willRegister(
        with form: any RegisterForm,
        on request: Request,
    ) async throws {
        try await _willRegister?(form, request)
    }

    public func didRegister(
        user: any User,
        on request: Request,
    ) async {
        await _didRegister?(user, request)
    }
    
    public func willLogin(
        user: any User,
        on request: Request,
    ) async throws {
        try await _willLogin?(user, request)
    }

    public func didLogin(
        user: any User,
        on request: Request,
    ) async {
        await _didLogin?(user, request)
    }

    public func willLogout(
        user: any User,
        on request: Request,
    ) async throws {
        try await _willLogout?(user, request)
    }

    public func didLogout(
        user: any User,
        on request: Request,
    ) async {
        await _didLogout?(user, request)
    }
}

public extension Passage.Hooks.Account where Self == _AccountHooksClosures {

    static func hook(
        willRegisterUser : (@Sendable (any RegisterForm, Request) async throws -> Void)? = nil,
        didRegisterUser  : (@Sendable (any User, Request) async -> Void)? = nil,
        willLoginUser    : (@Sendable (any User, Request) async throws -> Void)? = nil,
        didLoginUser     : (@Sendable (any User, Request) async -> Void)? = nil,
        willLogoutUser   : (@Sendable (any User, Request) async throws -> Void)? = nil,
        didLogoutUser    : (@Sendable (any User, Request) async -> Void)? = nil,
    ) -> some Passage.Hooks.Account {
        _AccountHooksClosures(
            _willRegister: willRegisterUser,
            _didRegister: didRegisterUser,
            _willLogin: willLoginUser,
            _didLogin: didLoginUser,
            _willLogout: willLogoutUser,
            _didLogout: didLogoutUser,
        )
    }

}

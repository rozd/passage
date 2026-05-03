public import Vapor

public extension Passage.Hooks {

    protocol Passkey: Sendable {

        // MARK: Guest Registration Hooks

        func willBeginGuestRegistration(
            with form: any PasskeyGuestRegistrationForm,
            as entity: PublicKeyCredentialUserEntity,
            on request: Request,
        ) async throws

        func didBeginGuestRegistration(
            with result: PasskeyBeginResult,
            on request: Request,
        ) async

        func willFinishGuestRegistration(
            with identifier: Identifier?,
            on request: Request,
        ) async throws

        func didFinishGuestRegistration(
            with credential: StoredPasskeyCredential,
            for user: any User,
            on request: Request,
        ) async

        // MARK: Registration Hooks

        func willBeginRegistration(
            for user: any User,
            as entity: PublicKeyCredentialUserEntity,
            on request: Request
        ) async throws

        func didBeginRegistration(
            with result: PasskeyBeginResult,
            for user: any User,
            on request: Request
        ) async

        func willFinishRegistration(
            for user: (any User)?,
            on request: Request,
        ) async throws

        func didFinishRegistration(
            with credential: StoredPasskeyCredential,
            for user: any User,
            on request: Request,
        ) async

        // MARK: Authentication Hooks

        func willBeginAuthentication(
            on request: Request,
        ) async throws

        func didBeginAuthentication(
            with result: PasskeyBeginResult,
            on request: Request,
        ) async

        func willFinishAuthentication(
            with credential: StoredPasskeyCredential,
            for user: any User,
            on request: Request,
        ) async throws

        func didFinishAuthentication(
            with credential: StoredPasskeyCredential,
            for user: any User,
            code: String,
            on request: Request,
        ) async
    }

}

// MARK: - Default Implementation

public extension Passage.Hooks.Passkey {

    func willBeginGuestRegistration(
        with form: any PasskeyGuestRegistrationForm,
        as entity: PublicKeyCredentialUserEntity,
        on request: Request,
    ) async throws {}

    func didBeginGuestRegistration(
        with result: PasskeyBeginResult,
        on request: Request,
    ) async {}

    func willFinishGuestRegistration(
        with identifier: Identifier?,
        on request: Request,
    ) async throws {}

    func didFinishGuestRegistration(
        with credential: StoredPasskeyCredential,
        for user: any User,
        on request: Request,
    ) async {}

    func willBeginRegistration(
        for user: any User,
        as entity: PublicKeyCredentialUserEntity,
        on request: Request
    ) async throws {}

    func didBeginRegistration(
        with result: PasskeyBeginResult,
        for user: any User,
        on request: Request
    ) async {}

    func willFinishRegistration(
        for user: (any User)?,
        on request: Request,
    ) async throws {}

    func didFinishRegistration(
        with credential: StoredPasskeyCredential,
        for user: any User,
        on request: Request,
    ) async {}

    func willBeginAuthentication(
        on request: Request,
    ) async throws {}

    func didBeginAuthentication(
        with result: PasskeyBeginResult,
        on request: Request,
    ) async {}

    func willFinishAuthentication(
        with credential: StoredPasskeyCredential,
        for user: any User,
        on request: Request,
    ) async throws {}

    func didFinishAuthentication(
        with credential: StoredPasskeyCredential,
        for user: any User,
        code: String,
        on request: Request,
    ) async {}
}

// MARK: - Closure-Based Hooks

public struct _PasskeyHooksClosures: Passage.Hooks.Passkey {

    let _willBeginGuestRegistration: (@Sendable (any PasskeyGuestRegistrationForm, PublicKeyCredentialUserEntity, Request) async throws -> Void)?
    let _didBeginGuestRegistration: (@Sendable (PasskeyBeginResult, Request) async -> Void)?
    let _willFinishGuestRegistration: (@Sendable (Identifier?, Request) async throws -> Void)?
    let _didFinishGuestRegistration: (@Sendable (StoredPasskeyCredential, any User, Request) async -> Void)?

    let _willBeginRegistration: (@Sendable (any User, PublicKeyCredentialUserEntity, Request) async throws -> Void)?
    let _didBeginRegistration: (@Sendable (PasskeyBeginResult, any User, Request) async -> Void)?
    let _willFinishRegistration: (@Sendable ((any User)?, Request) async throws -> Void)?
    let _didFinishRegistration: (@Sendable (StoredPasskeyCredential, any User, Request) async -> Void)?

    let _willBeginAuthentication: (@Sendable (Request) async throws -> Void)?
    let _didBeginAuthentication: (@Sendable (PasskeyBeginResult, Request) async -> Void)?
    let _willFinishAuthentication: (@Sendable (StoredPasskeyCredential, any User, Request) async throws -> Void)?
    let _didFinishAuthentication: (@Sendable (StoredPasskeyCredential, any User, String, Request) async -> Void)?

    public func willBeginGuestRegistration(
        with form: any PasskeyGuestRegistrationForm,
        as entity: PublicKeyCredentialUserEntity,
        on request: Request,
    ) async throws {
        try await _willBeginGuestRegistration?(form, entity, request)
    }

    public func didBeginGuestRegistration(
        with result: PasskeyBeginResult,
        on request: Request,
    ) async {
        await _didBeginGuestRegistration?(result, request)
    }

    public func willFinishGuestRegistration(
        with identifier: Identifier?,
        on request: Request,
    ) async throws {
        try await _willFinishGuestRegistration?(identifier, request)
    }

    public func didFinishGuestRegistration(
        with credential: StoredPasskeyCredential,
        for user: any User,
        on request: Request,
    ) async {
        await _didFinishGuestRegistration?(credential, user, request)
    }

    public func willBeginRegistration(
        for user: any User,
        as entity: PublicKeyCredentialUserEntity,
        on request: Request
    ) async throws {
        try await _willBeginRegistration?(user, entity, request)
    }

    public func didBeginRegistration(
        with result: PasskeyBeginResult,
        for user: any User,
        on request: Request
    ) async {
        try await _didBeginRegistration?(result, user, request)
    }

    public func willFinishRegistration(
        for user: (any User)?,
        on request: Request,
    ) async throws {
        try await _willFinishRegistration?(user, request)
    }

    public func didFinishRegistration(
        with credential: StoredPasskeyCredential,
        for user: any User,
        on request: Request,
    ) async {
        try await _didFinishRegistration?(credential, user, request)
    }

    public func willBeginAuthentication(
        on request: Request,
    ) async throws {
        try await _willBeginAuthentication?(request)
    }

    public func didBeginAuthentication(
        with result: PasskeyBeginResult,
        on request: Request,
    ) async {
        await _didBeginAuthentication?(result, request)
    }

    public func willFinishAuthentication(
        with credential: StoredPasskeyCredential,
        for user: any User,
        on request: Request,
    ) async throws {
        try await _willFinishAuthentication?(credential, user, request)
    }

    public func didFinishAuthentication(
        with credential: StoredPasskeyCredential,
        for user: any User,
        code: String,
        on request: Request,
    ) async {
        await _didFinishAuthentication?(credential, user, code, request)
    }
}

public extension Passage.Hooks.Passkey where Self == _PasskeyHooksClosures {

    static func hook(
        willBeginGuestRegistration  : (@Sendable (any PasskeyGuestRegistrationForm, PublicKeyCredentialUserEntity, Request) async throws -> Void)? = nil,
        didBeginGuestRegistration   : (@Sendable (PasskeyBeginResult, Request) async -> Void)? = nil,
        willFinishGuestRegistration : (@Sendable (Identifier?, Request) async throws -> Void)? = nil,
        didFinishGuestRegistration  : (@Sendable (StoredPasskeyCredential, any User, Request) async -> Void)? = nil,

        willBeginRegistration       : (@Sendable (any User, PublicKeyCredentialUserEntity, Request) async throws -> Void)? = nil,
        didBeginRegistration        : (@Sendable (PasskeyBeginResult, any User, Request) async -> Void)? = nil,
        willFinishRegistration      : (@Sendable ((any User)?, Request) async throws -> Void)? = nil,
        didFinishRegistration       : (@Sendable (StoredPasskeyCredential, any User, Request) async -> Void)? = nil,

        willBeginAuthentication     : (@Sendable (Request) async throws -> Void)? = nil,
        didBeginAuthentication      : (@Sendable (PasskeyBeginResult, Request) async -> Void)? = nil,
        willFinishAuthentication    : (@Sendable (StoredPasskeyCredential, any User, Request) async throws -> Void)? = nil,
        didFinishAuthentication     : (@Sendable (StoredPasskeyCredential, any User, String, Request) async -> Void)? = nil,
    ) -> some Passage.Hooks.Passkey {
        _PasskeyHooksClosures(
            _willBeginGuestRegistration : willBeginGuestRegistration,
            _didBeginGuestRegistration  : didBeginGuestRegistration,
            _willFinishGuestRegistration: willFinishGuestRegistration,
            _didFinishGuestRegistration : didFinishGuestRegistration,
            _willBeginRegistration      : willBeginRegistration,
            _didBeginRegistration       : didBeginRegistration,
            _willFinishRegistration     : willFinishRegistration,
            _didFinishRegistration      : didFinishRegistration,
            _willBeginAuthentication    : willBeginAuthentication,
            _didBeginAuthentication     : didBeginAuthentication,
            _willFinishAuthentication   : willFinishAuthentication,
            _didFinishAuthentication    : didFinishAuthentication
        )
    }

}

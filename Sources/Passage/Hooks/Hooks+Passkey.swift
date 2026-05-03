public import Vapor

public extension Passage.Hooks {

    protocol Passkey: Sendable {

        // MARK: Guest Registration Hooks

        func willBeginGuestRegistration(
            with form: any PasskeySignupForm,
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
    }

}

// MARK: - Default Implementation

public extension Passage.Hooks.Passkey {

    func willBeginGuestRegistration(
        with form: any PasskeySignupForm,
        as entity: PublicKeyCredentialUserEntity,
        on request: Request,
    ) async throws {}

    func didBeginGuestRegistration(
        with result: PasskeyBeginResult,
        on request: Request,
    ) async throws {}

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
    ) async throws {}

    func willFinishRegistration(
        for user: (any User)?,
        on request: Request,
    ) async throws {}

    func didFinishRegistration(
        with credential: StoredPasskeyCredential,
        for user: any User,
        on request: Request,
    ) async {}
}

// MARK: - Closure-Based Hooks

public struct _PasskeyHooksClosures: Passage.Hooks.Passkey {

    let _willBeginGuestRegistration: (@Sendable (any PasskeySignupForm, PublicKeyCredentialUserEntity, Request) async throws -> Void)?
    let _didBeginGuestRegistration: (@Sendable (PasskeyBeginResult, Request) async -> Void)?
    let _willFinishGuestRegistration: (@Sendable (Identifier?, Request) async throws -> Void)?
    let _didFinishGuestRegistration: (@Sendable (any User, Request, StoredPasskeyCredential) async -> Void)?

    let _willBeginRegistration: (@Sendable (any User, PublicKeyCredentialUserEntity, Request) async throws -> Void)?
    let _didBeginRegistration: (@Sendable (PasskeyBeginResult, any User, Request) async -> Void)?
    let _willFinishRegistration: (@Sendable ((any User)?, Request) async throws -> Void)?
    let _didFinishRegistration: (@Sendable (any User, Request, StoredPasskeyCredential) async -> Void)?

    public func willBeginGuestRegistration(
        with form: any PasskeySignupForm,
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
        for user: any User,
        on request: Request,
        with credential: StoredPasskeyCredential,
    ) async {
        await _didFinishGuestRegistration?(user, request, credential)
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
        for user: any User,
        on request: Request,
        with credential: StoredPasskeyCredential,
    ) async {
        try await _didFinishRegistration?(user, request, credential)
    }
}

public extension Passage.Hooks.Passkey where Self == _PasskeyHooksClosures {

    static func hook(
        willBeginGuestRegistration  : (@Sendable (any PasskeySignupForm, PublicKeyCredentialUserEntity, Request) async throws -> Void)? = nil,
        didBeginGuestRegistration   : (@Sendable (PasskeyBeginResult, Request) async -> Void)? = nil,
        willFinishGuestRegistration : (@Sendable (Identifier?, Request) async throws -> Void)? = nil,
        didFinishGuestRegistration  : (@Sendable (any User, Request, StoredPasskeyCredential) async -> Void)? = nil,

        willBeginRegistration       : (@Sendable (any User, PublicKeyCredentialUserEntity, Request) async throws -> Void)? = nil,
        didBeginRegistration        : (@Sendable (PasskeyBeginResult, any User, Request) async -> Void)? = nil,
        willFinishRegistration      : (@Sendable ((any User)?, Request) async throws -> Void)? = nil,
        didFinishRegistration       : (@Sendable (any User, Request, StoredPasskeyCredential) async -> Void)? = nil
    ) -> some Passage.Hooks.Passkey {
        _PasskeyHooksClosures(
            _willBeginGuestRegistration : willBeginGuestRegistration,
            _didBeginGuestRegistration  : didBeginGuestRegistration,
            _willFinishGuestRegistration: willFinishGuestRegistration,
            _didFinishGuestRegistration : didFinishGuestRegistration,
            _willBeginRegistration      : willBeginRegistration,
            _didBeginRegistration       : didBeginRegistration,
            _willFinishRegistration     : willFinishRegistration,
            _didFinishRegistration      : didFinishRegistration
        )
    }

}

public import Vapor

public extension Passage.Hooks {

    protocol Passkey: Sendable {

        // MARK: Guest Registration Hooks

        func willBeginGuestRegistration(
            with form: any PasskeySignupForm,
            on request: Request,
        ) async throws
    }

}

// MARK: - Default Implementation

public extension Passage.Hooks.Passkey {

    func willBeginGuestRegistration(
        with form: any PasskeySignupForm,
        on request: Request,
    ) async throws {}
}

// MARK: - Closure-Based Hooks

public struct _PasskeyHooksClosures: Passage.Hooks.Passkey {

    let _willBeginGuestRegistration: (@Sendable (any PasskeySignupForm, Request) async throws -> Void)?

    public func willBeginGuestRegistration(
        with form: any PasskeySignupForm,
        on request: Request,
    ) async throws {
        try await _willBeginGuestRegistration?(form, request)
    }
}

public extension Passage.Hooks.Passkey where Self == _PasskeyHooksClosures {

    static func hook(
        willBeginGuestRegistration: (@Sendable (any PasskeySignupForm, Request) async throws -> Void)? = nil,
    ) -> some Passage.Hooks.Passkey {
        _PasskeyHooksClosures(
            _willBeginGuestRegistration: willBeginGuestRegistration
        )
    }

}

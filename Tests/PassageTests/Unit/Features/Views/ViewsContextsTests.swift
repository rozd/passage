import Testing
import Vapor
@testable import Passage

@Suite
struct `Views Contexts Tests` {

    // MARK: - Context Generic Type Tests

    @Test
    func `Context initializes with theme and params`() {
        struct TestParams: Sendable, Encodable {
            let value: String
        }

        let theme = Passage.Views.Theme(colors: .defaultLight)
        let params = TestParams(value: "test")
        let resolved = theme.resolve(for: .light)

        let context = Passage.Views.Context(theme: resolved, params: params)

        #expect(context.params.value == "test")
        #expect(context.theme.colors.primary == resolved.colors.primary)
    }

    // MARK: - LoginViewParams Tests

    @Test
    func `LoginViewParams initialization`() {
        let context = Passage.Views.LoginViewParams(
            byEmail: true,
            byPhone: false,
            byUsername: false,
            withApple: false,
            withGoogle: true,
            withGitHub: false,
            error: nil,
            success: nil,
            registerLink: "/register",
            resetPasswordLink: "/reset",
            byEmailMagicLink: nil,
            magicLinkRequestLink: nil
        )

        #expect(context.byEmail == true)
        #expect(context.byPhone == false)
        #expect(context.withGoogle == true)
        #expect(context.registerLink == "/register")
        #expect(context.resetPasswordLink == "/reset")
    }

    @Test
    func `LoginViewParams copyWith updates only specified fields`() {
        let original = Passage.Views.LoginViewParams(
            byEmail: true,
            byPhone: false,
            byUsername: false,
            withApple: false,
            withGoogle: false,
            withGitHub: false,
            error: nil,
            success: nil,
            registerLink: nil,
            resetPasswordLink: nil,
            byEmailMagicLink: nil,
            magicLinkRequestLink: nil
        )

        let updated = original.copyWith(
            withGoogle: true,
            error: "An error occurred",
            registerLink: "/register"
        )

        // Updated fields
        #expect(updated.withGoogle == true)
        #expect(updated.error == "An error occurred")
        #expect(updated.registerLink == "/register")

        // Unchanged fields
        #expect(updated.byEmail == true)
        #expect(updated.byPhone == false)
        #expect(updated.withApple == false)
        #expect(updated.resetPasswordLink == nil)
    }

    @Test
    func `LoginViewParams copyWith preserves original when no params`() {
        let original = Passage.Views.LoginViewParams(
            byEmail: true,
            byPhone: false,
            byUsername: false,
            withApple: true,
            withGoogle: false,
            withGitHub: false,
            error: "Original error",
            success: nil,
            registerLink: "/original",
            resetPasswordLink: "/reset",
            byEmailMagicLink: nil,
            magicLinkRequestLink: nil
        )

        let copy = original.copyWith()

        #expect(copy.byEmail == original.byEmail)
        #expect(copy.withApple == original.withApple)
        #expect(copy.error == original.error)
        #expect(copy.registerLink == original.registerLink)
    }

    // MARK: - RegisterViewParams Tests

    @Test
    func `RegisterViewParams initialization`() {
        let context = Passage.Views.RegisterViewParams(
            byEmail: true,
            byPhone: false,
            byUsername: false,
            withApple: false,
            withGoogle: true,
            withGitHub: false,
            error: nil,
            success: "Registration successful",
            loginLink: "/login"
        )

        #expect(context.byEmail == true)
        #expect(context.withGoogle == true)
        #expect(context.success == "Registration successful")
        #expect(context.loginLink == "/login")
    }

    @Test
    func `RegisterViewParams copyWith updates only specified fields`() {
        let original = Passage.Views.RegisterViewParams(
            byEmail: true,
            byPhone: false,
            byUsername: false,
            withApple: false,
            withGoogle: false,
            withGitHub: false,
            error: nil,
            success: nil,
            loginLink: nil
        )

        let updated = original.copyWith(
            withGitHub: true,
            success: "Success message",
            loginLink: "/signin"
        )

        #expect(updated.withGitHub == true)
        #expect(updated.success == "Success message")
        #expect(updated.loginLink == "/signin")
        #expect(updated.byEmail == true)
        #expect(updated.withGoogle == false)
    }

    // MARK: - ResetPasswordRequestViewParams Tests

    @Test
    func `ResetPasswordRequestViewParams initialization`() {
        let context = Passage.Views.ResetPasswordRequestViewParams(
            byEmail: true,
            byPhone: false,
            error: nil,
            success: nil
        )

        #expect(context.byEmail == true)
        #expect(context.byPhone == false)
        #expect(context.error == nil)
        #expect(context.success == nil)
    }

    @Test
    func `ResetPasswordRequestViewParams copyWith updates fields`() {
        let original = Passage.Views.ResetPasswordRequestViewParams(
            byEmail: true,
            byPhone: false,
            error: nil,
            success: nil
        )

        let updated = original.copyWith(
            error: "Invalid email",
            success: "Email sent"
        )

        #expect(updated.error == "Invalid email")
        #expect(updated.success == "Email sent")
        #expect(updated.byEmail == true)
    }

    @Test
    func `ResetPasswordRequestViewParams with both email and phone`() {
        let context = Passage.Views.ResetPasswordRequestViewParams(
            byEmail: true,
            byPhone: true,
            error: nil,
            success: nil
        )

        #expect(context.byEmail == true)
        #expect(context.byPhone == true)
    }

    // MARK: - ResetPasswordConfirmViewParams Tests

    @Test
    func `ResetPasswordConfirmViewParams initialization`() {
        let context = Passage.Views.ResetPasswordConfirmViewParams(
            byEmail: true,
            byPhone: false,
            code: "ABC123",
            email: "test@example.com",
            error: nil,
            success: nil
        )

        #expect(context.byEmail == true)
        #expect(context.code == "ABC123")
        #expect(context.email == "test@example.com")
    }

    @Test
    func `ResetPasswordConfirmViewParams copyWith preserves code`() {
        let original = Passage.Views.ResetPasswordConfirmViewParams(
            byEmail: true,
            byPhone: false,
            code: "ORIGINAL_CODE",
            email: "original@example.com",
            error: nil,
            success: nil
        )

        let updated = original.copyWith(
            email: "new@example.com",
            error: "Invalid code"
        )

        // Code should be preserved
        #expect(updated.code == "ORIGINAL_CODE")
        #expect(updated.email == "new@example.com")
        #expect(updated.error == "Invalid code")
    }

    @Test
    func `ResetPasswordConfirmViewParams copyWith updates specified fields`() {
        let original = Passage.Views.ResetPasswordConfirmViewParams(
            byEmail: true,
            byPhone: false,
            code: "123456",
            email: nil,
            error: nil,
            success: nil
        )

        let updated = original.copyWith(
            byPhone: true,
            email: "test@example.com",
            success: "Password reset successful"
        )

        #expect(updated.byPhone == true)
        #expect(updated.email == "test@example.com")
        #expect(updated.success == "Password reset successful")
        #expect(updated.code == "123456")
    }

    // MARK: - Content Conformance Tests

    @Test
    func `LoginViewParams conforms to Content`() {
        let context = Passage.Views.LoginViewParams(
            byEmail: true, byPhone: false, byUsername: false,
            withApple: false, withGoogle: false, withGitHub: false,
            error: nil, success: nil, registerLink: nil, resetPasswordLink: nil,
            byEmailMagicLink: nil, magicLinkRequestLink: nil
        )
        let _: any Content = context
    }

    @Test
    func `RegisterViewParams conforms to Content`() {
        let context = Passage.Views.RegisterViewParams(
            byEmail: true, byPhone: false, byUsername: false,
            withApple: false, withGoogle: false, withGitHub: false,
            error: nil, success: nil, loginLink: nil
        )
        let _: any Content = context
    }

    @Test
    func `ResetPasswordRequestViewParams conforms to Content`() {
        let context = Passage.Views.ResetPasswordRequestViewParams(
            byEmail: true, byPhone: false,
            error: nil, success: nil
        )
        let _: any Content = context
    }

    @Test
    func `ResetPasswordConfirmViewParams conforms to Content`() {
        let context = Passage.Views.ResetPasswordConfirmViewParams(
            byEmail: true, byPhone: false,
            code: "123", email: nil,
            error: nil, success: nil
        )
        let _: any Content = context
    }

    // MARK: - Context Immutability Tests

    @Test
    func `LoginViewParams copyWith creates new instance`() {
        let original = Passage.Views.LoginViewParams(
            byEmail: true, byPhone: false, byUsername: false,
            withApple: false, withGoogle: false, withGitHub: false,
            error: nil, success: nil, registerLink: nil, resetPasswordLink: nil,
            byEmailMagicLink: nil, magicLinkRequestLink: nil
        )

        let copy = original.copyWith(error: "New error")

        // Original should be unchanged
        #expect(original.error == nil)
        #expect(copy.error == "New error")
    }

    @Test
    func `RegisterViewParams copyWith creates new instance`() {
        let original = Passage.Views.RegisterViewParams(
            byEmail: true, byPhone: false, byUsername: false,
            withApple: false, withGoogle: false, withGitHub: false,
            error: nil, success: nil, loginLink: nil
        )

        let copy = original.copyWith(success: "Success!")

        #expect(original.success == nil)
        #expect(copy.success == "Success!")
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `LoginViewParams conforms to Sendable`() {
        assertSendable(Passage.Views.LoginViewParams(
            byEmail: true, byPhone: false, byUsername: false,
            withApple: false, withGoogle: false, withGitHub: false,
            error: nil, success: nil, registerLink: nil, resetPasswordLink: nil,
            byEmailMagicLink: nil, magicLinkRequestLink: nil
        ))
    }

    @Test
    func `RegisterViewParams conforms to Sendable`() {
        assertSendable(Passage.Views.RegisterViewParams(
            byEmail: true, byPhone: false, byUsername: false,
            withApple: false, withGoogle: false, withGitHub: false,
            error: nil, success: nil, loginLink: nil
        ))
    }

    @Test
    func `ResetPasswordRequestViewParams conforms to Sendable`() {
        assertSendable(Passage.Views.ResetPasswordRequestViewParams(
            byEmail: true, byPhone: false, error: nil, success: nil
        ))
    }

    @Test
    func `ResetPasswordConfirmViewParams conforms to Sendable`() {
        assertSendable(Passage.Views.ResetPasswordConfirmViewParams(
            byEmail: true, byPhone: false, code: "123456",
            email: "test@example.com", error: nil, success: nil
        ))
    }

    @Test
    func `MagicLinkRequestViewParams conforms to Sendable`() {
        assertSendable(Passage.Views.MagicLinkRequestViewParams(
            byEmail: true, error: nil, success: nil, identifier: nil
        ))
    }

    @Test
    func `MagicLinkVerifyViewParams conforms to Sendable`() {
        assertSendable(Passage.Views.MagicLinkVerifyViewParams(
            error: nil, success: nil, redirectUrl: nil, loginLink: nil
        ))
    }

    @Test
    func `OAuthLinkSelectViewContext conforms to Sendable`() {
        let candidate = Passage.Views.LinkAccountSelectViewParams.Candidate(
            userId: "user123", maskedEmail: "t***@example.com", maskedPhone: nil
        )
        assertSendable(candidate)
        assertSendable(Passage.Views.LinkAccountSelectViewParams(
            provider: "google", candidates: [candidate], error: nil
        ))
    }

    @Test
    func `OAuthLinkVerifyViewContext conforms to Sendable`() {
        assertSendable(Passage.Views.LinkAccountVerifyViewParams(
            maskedEmail: "t***@example.com", hasPassword: true,
            canUseEmailCode: true, error: nil
        ))
    }
}

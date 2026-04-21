import Testing
import Vapor
@testable import Passage

@Suite
struct `Default Forms Tests` {

    // MARK: - DefaultLoginForm Tests

    @Test
    func `DefaultLoginForm initialization`() {
        let form = Passage.DefaultLoginForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123"
        )

        #expect(form.email == "test@example.com")
        #expect(form.phone == nil)
        #expect(form.username == nil)
        #expect(form.password == "password123")
    }

    @Test
    func `DefaultLoginForm conforms to LoginForm`() {
        let form: any LoginForm = Passage.DefaultLoginForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123"
        )
        #expect(form is Passage.DefaultLoginForm)
    }

    @Test
    func `DefaultLoginForm validate does not throw`() throws {
        let form = Passage.DefaultLoginForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123"
        )
        try form.validate() // Should not throw
    }

    // MARK: - DefaultRegisterForm Tests

    @Test
    func `DefaultRegisterForm initialization`() {
        let form = Passage.DefaultRegisterForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )

        #expect(form.email == "test@example.com")
        #expect(form.phone == nil)
        #expect(form.username == nil)
        #expect(form.password == "password123")
        #expect(form.confirmPassword == "password123")
    }

    @Test
    func `DefaultRegisterForm conforms to RegisterForm`() {
        let form: any RegisterForm = Passage.DefaultRegisterForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )
        #expect(form is Passage.DefaultRegisterForm)
    }

    @Test
    func `DefaultRegisterForm validate succeeds when passwords match`() throws {
        let form = Passage.DefaultRegisterForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )
        try form.validate() // Should not throw
    }

    @Test
    func `DefaultRegisterForm validate throws when passwords don't match`() {
        let form = Passage.DefaultRegisterForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "different_password"
        )

        #expect(throws: AuthenticationError.passwordsDoNotMatch) {
            try form.validate()
        }
    }

    // MARK: - DefaultRefreshTokenForm Tests

    @Test
    func `DefaultRefreshTokenForm initialization`() {
        let form = Passage.DefaultRefreshTokenForm(refreshToken: "my_token")
        #expect(form.refreshToken == "my_token")
    }

    @Test
    func `DefaultRefreshTokenForm conforms to RefreshTokenForm`() {
        let form: any RefreshTokenForm = Passage.DefaultRefreshTokenForm(refreshToken: "my_token")
        #expect(form is Passage.DefaultRefreshTokenForm)
    }

    @Test
    func `DefaultRefreshTokenForm validate does not throw`() throws {
        let form = Passage.DefaultRefreshTokenForm(refreshToken: "my_token")
        try form.validate() // Should not throw
    }

    // MARK: - DefaultLogoutForm Tests

    @Test
    func `DefaultLogoutForm initialization`() {
        let form = Passage.DefaultLogoutForm()
        let _: any LogoutForm = form
        #expect(form is Passage.DefaultLogoutForm)
    }

    @Test
    func `DefaultLogoutForm conforms to LogoutForm`() {
        let form: any LogoutForm = Passage.DefaultLogoutForm()
        #expect(form is Passage.DefaultLogoutForm)
    }

    // MARK: - DefaultEmailVerificationRequestForm Tests

    @Test
    func `DefaultEmailVerificationRequestForm initialization`() {
        let form = Passage.DefaultEmailVerificationRequestForm(email: "test@example.com")
        #expect(form.email == "test@example.com")
    }

    @Test
    func `DefaultEmailVerificationRequestForm conforms to EmailVerificationRequestForm`() {
        let form: any EmailVerificationRequestForm = Passage.DefaultEmailVerificationRequestForm(email: "test@example.com")
        #expect(form is Passage.DefaultEmailVerificationRequestForm)
    }

    // MARK: - DefaultEmailVerificationConfirmForm Tests

    @Test
    func `DefaultEmailVerificationConfirmForm initialization`() {
        let form = Passage.DefaultEmailVerificationConfirmForm(code: "123456", email: "test@example.com")
        #expect(form.code == "123456")
        #expect(form.email == "test@example.com")
    }

    @Test
    func `DefaultEmailVerificationConfirmForm conforms to EmailVerificationConfirmForm`() {
        let form = Passage.DefaultEmailVerificationConfirmForm(code: "123456", email: "test@example.com")
        #expect(form is any EmailVerificationConfirmForm)
    }

    // MARK: - DefaultPhoneVerificationRequestForm Tests

    @Test
    func `DefaultPhoneVerificationRequestForm initialization`() {
        let form = Passage.DefaultPhoneVerificationRequestForm(phone: "+1234567890")
        #expect(form.phone == "+1234567890")
    }

    @Test
    func `DefaultPhoneVerificationRequestForm conforms to PhoneVerificationRequestForm`() {
        let form: any PhoneVerificationRequestForm = Passage.DefaultPhoneVerificationRequestForm(phone: "+1234567890")
        #expect(form is Passage.DefaultPhoneVerificationRequestForm)
    }

    // MARK: - DefaultPhoneVerificationConfirmForm Tests

    @Test
    func `DefaultPhoneVerificationConfirmForm initialization`() {
        let form = Passage.DefaultPhoneVerificationConfirmForm(code: "123456", phone: "+1234567890")
        #expect(form.code == "123456")
        #expect(form.phone == "+1234567890")
    }

    @Test
    func `DefaultPhoneVerificationConfirmForm conforms to PhoneVerificationConfirmForm`() {
        let form = Passage.DefaultPhoneVerificationConfirmForm(code: "123456", phone: "+1234567890")
        #expect(form is any PhoneVerificationConfirmForm)
    }

    // MARK: - DefaultEmailPasswordResetRequestForm Tests

    @Test
    func `DefaultEmailPasswordResetRequestForm initialization`() {
        let form = Passage.DefaultEmailPasswordResetRequestForm(email: "test@example.com")
        #expect(form.email == "test@example.com")
    }

    @Test
    func `DefaultEmailPasswordResetRequestForm conforms to protocol`() {
        let form: any EmailPasswordResetRequestForm = Passage.DefaultEmailPasswordResetRequestForm(email: "test@example.com")
        #expect(form is Passage.DefaultEmailPasswordResetRequestForm)
    }

    // MARK: - DefaultEmailPasswordResetVerifyForm Tests

    @Test
    func `DefaultEmailPasswordResetVerifyForm initialization`() {
        let form = Passage.DefaultEmailPasswordResetVerifyForm(
            email: "test@example.com",
            code: "123456",
            newPassword: "newpassword123"
        )

        #expect(form.email == "test@example.com")
        #expect(form.code == "123456")
        #expect(form.newPassword == "newpassword123")
    }

    @Test
    func `DefaultEmailPasswordResetVerifyForm conforms to protocol`() {
        let form: any EmailPasswordResetVerifyForm = Passage.DefaultEmailPasswordResetVerifyForm(
            email: "test@example.com",
            code: "123456",
            newPassword: "newpassword123"
        )
        #expect(form is Passage.DefaultEmailPasswordResetVerifyForm)
    }

    // MARK: - DefaultEmailPasswordResetResendForm Tests

    @Test
    func `DefaultEmailPasswordResetResendForm initialization`() {
        let form = Passage.DefaultEmailPasswordResetResendForm(email: "test@example.com")
        #expect(form.email == "test@example.com")
    }

    @Test
    func `DefaultEmailPasswordResetResendForm conforms to protocol`() {
        let form: any EmailPasswordResetResendForm = Passage.DefaultEmailPasswordResetResendForm(email: "test@example.com")
        #expect(form is Passage.DefaultEmailPasswordResetResendForm)
    }

    // MARK: - DefaultPhonePasswordResetRequestForm Tests

    @Test
    func `DefaultPhonePasswordResetRequestForm initialization`() {
        let form = Passage.DefaultPhonePasswordResetRequestForm(phone: "+1234567890")
        #expect(form.phone == "+1234567890")
    }

    @Test
    func `DefaultPhonePasswordResetRequestForm conforms to protocol`() {
        let form: any PhonePasswordResetRequestForm = Passage.DefaultPhonePasswordResetRequestForm(phone: "+1234567890")
        #expect(form is Passage.DefaultPhonePasswordResetRequestForm)
    }

    // MARK: - DefaultPhonePasswordResetVerifyForm Tests

    @Test
    func `DefaultPhonePasswordResetVerifyForm initialization`() {
        let form = Passage.DefaultPhonePasswordResetVerifyForm(
            phone: "+1234567890",
            code: "123456",
            newPassword: "newpassword123"
        )

        #expect(form.phone == "+1234567890")
        #expect(form.code == "123456")
        #expect(form.newPassword == "newpassword123")
    }

    @Test
    func `DefaultPhonePasswordResetVerifyForm conforms to protocol`() {
        let form: any PhonePasswordResetVerifyForm = Passage.DefaultPhonePasswordResetVerifyForm(
            phone: "+1234567890",
            code: "123456",
            newPassword: "newpassword123"
        )
        #expect(form is Passage.DefaultPhonePasswordResetVerifyForm)
    }

    // MARK: - DefaultPhonePasswordResetResendForm Tests

    @Test
    func `DefaultPhonePasswordResetResendForm initialization`() {
        let form = Passage.DefaultPhonePasswordResetResendForm(phone: "+1234567890")
        #expect(form.phone == "+1234567890")
    }

    @Test
    func `DefaultPhonePasswordResetResendForm conforms to protocol`() {
        let form: any PhonePasswordResetResendForm = Passage.DefaultPhonePasswordResetResendForm(phone: "+1234567890")
        #expect(form is Passage.DefaultPhonePasswordResetResendForm)
    }

    // MARK: - All Default Forms Tests

    @Test
    func `All default forms conform to Content`() {
        let forms: [any Content] = [
            Passage.DefaultLoginForm(email: "test@example.com", phone: nil, username: nil, password: "password123"),
            Passage.DefaultRegisterForm(email: "test@example.com", phone: nil, username: nil, password: "password123", confirmPassword: "password123"),
            Passage.DefaultRefreshTokenForm(refreshToken: "token"),
            Passage.DefaultLogoutForm(),
            Passage.DefaultEmailVerificationRequestForm(email: "test@example.com"),
            Passage.DefaultEmailVerificationConfirmForm(code: "123456", email: "test@example.com"),
            Passage.DefaultPhoneVerificationRequestForm(phone: "+1234567890"),
            Passage.DefaultPhoneVerificationConfirmForm(code: "123456", phone: "+1234567890"),
            Passage.DefaultEmailPasswordResetRequestForm(email: "test@example.com"),
            Passage.DefaultPhonePasswordResetRequestForm(phone: "+1234567890")
        ]

        #expect(forms.count == 10)
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `DefaultLoginForm conforms to Sendable`() {
        assertSendable(Passage.DefaultLoginForm(email: "test@example.com", phone: nil, username: nil, password: "password123"))
    }

    @Test
    func `DefaultRegisterForm conforms to Sendable`() {
        assertSendable(Passage.DefaultRegisterForm(email: "test@example.com", phone: nil, username: nil, password: "password123", confirmPassword: "password123"))
    }

    @Test
    func `DefaultRefreshTokenForm conforms to Sendable`() {
        assertSendable(Passage.DefaultRefreshTokenForm(refreshToken: "token"))
    }

    @Test
    func `DefaultExchangeCodeForm conforms to Sendable`() {
        assertSendable(Passage.DefaultExchangeCodeForm(code: "code123"))
    }

    @Test
    func `DefaultLogoutForm conforms to Sendable`() {
        assertSendable(Passage.DefaultLogoutForm())
    }

    @Test
    func `DefaultEmailVerificationRequestForm conforms to Sendable`() {
        assertSendable(Passage.DefaultEmailVerificationRequestForm(email: "test@example.com"))
    }

    @Test
    func `DefaultEmailVerificationConfirmForm conforms to Sendable`() {
        assertSendable(Passage.DefaultEmailVerificationConfirmForm(code: "123456", email: "test@example.com"))
    }

    @Test
    func `DefaultPhoneVerificationRequestForm conforms to Sendable`() {
        assertSendable(Passage.DefaultPhoneVerificationRequestForm(phone: "+1234567890"))
    }

    @Test
    func `DefaultPhoneVerificationConfirmForm conforms to Sendable`() {
        assertSendable(Passage.DefaultPhoneVerificationConfirmForm(code: "123456", phone: "+1234567890"))
    }

    @Test
    func `DefaultEmailPasswordResetRequestForm conforms to Sendable`() {
        assertSendable(Passage.DefaultEmailPasswordResetRequestForm(email: "test@example.com"))
    }

    @Test
    func `DefaultEmailPasswordResetVerifyForm conforms to Sendable`() {
        assertSendable(Passage.DefaultEmailPasswordResetVerifyForm(email: "test@example.com", code: "123456", newPassword: "newpassword"))
    }

    @Test
    func `DefaultEmailPasswordResetResendForm conforms to Sendable`() {
        assertSendable(Passage.DefaultEmailPasswordResetResendForm(email: "test@example.com"))
    }

    @Test
    func `DefaultPhonePasswordResetRequestForm conforms to Sendable`() {
        assertSendable(Passage.DefaultPhonePasswordResetRequestForm(phone: "+1234567890"))
    }

    @Test
    func `DefaultPhonePasswordResetVerifyForm conforms to Sendable`() {
        assertSendable(Passage.DefaultPhonePasswordResetVerifyForm(phone: "+1234567890", code: "123456", newPassword: "newpassword"))
    }

    @Test
    func `DefaultPhonePasswordResetResendForm conforms to Sendable`() {
        assertSendable(Passage.DefaultPhonePasswordResetResendForm(phone: "+1234567890"))
    }

    @Test
    func `DefaultLinkAccountSelectForm conforms to Sendable`() {
        assertSendable(Passage.DefaultLinkAccountSelectForm(selectedUserId: "user123"))
    }

    @Test
    func `DefaultLinkAccountVerifyForm conforms to Sendable`() {
        assertSendable(Passage.DefaultLinkAccountVerifyForm(password: "password", verificationCode: nil))
    }

    @Test
    func `DefaultEmailMagicLinkRequestForm conforms to Sendable`() {
        assertSendable(Passage.DefaultEmailMagicLinkRequestForm(email: "test@example.com"))
    }

    @Test
    func `DefaultEmailMagicLinkVerifyForm conforms to Sendable`() {
        assertSendable(Passage.DefaultEmailMagicLinkVerifyForm(token: "token123"))
    }

    @Test
    func `DefaultEmailMagicLinkResendForm conforms to Sendable`() {
        assertSendable(Passage.DefaultEmailMagicLinkResendForm(email: "test@example.com"))
    }
}

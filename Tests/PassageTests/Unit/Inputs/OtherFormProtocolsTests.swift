import Testing
import Vapor
@testable import Passage

@Suite
struct `Other Form Protocols Tests` {

    // MARK: - RefreshTokenForm Tests

    struct MockRefreshTokenForm: RefreshTokenForm {
        static func validations(_ validations: inout Validations) {
            validations.add("refreshToken", as: String.self, is: !.empty)
        }

        let refreshToken: String

        func validate() throws {
            // No additional validation
        }
    }

    @Test
    func `RefreshTokenForm conforms to Form protocol`() {
        let form: any Form = MockRefreshTokenForm(refreshToken: "token123")
        #expect(form is MockRefreshTokenForm)
    }

    @Test
    func `RefreshTokenForm has refreshToken property`() {
        let form = MockRefreshTokenForm(refreshToken: "my_refresh_token")
        #expect(form.refreshToken == "my_refresh_token")
    }

    // MARK: - LogoutForm Tests

    struct MockLogoutForm: LogoutForm {
        static func validations(_ validations: inout Validations) {
            // No validations needed for logout
        }
    }

    @Test
    func `LogoutForm conforms to Form protocol`() {
        let form: any Form = MockLogoutForm()
        #expect(form is MockLogoutForm)
    }

    // MARK: - VerificationRequestForm Tests

    struct MockEmailVerificationRequestForm: EmailVerificationRequestForm {
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
        }

        let email: String
    }

    struct MockPhoneVerificationRequestForm: PhoneVerificationRequestForm {
        static func validations(_ validations: inout Validations) {
            validations.add("phone", as: String.self, is: .count(6...))
        }

        let phone: String
    }

    @Test
    func `EmailVerificationRequestForm conforms to Form`() {
        let form: any Form = MockEmailVerificationRequestForm(email: "test@example.com")
        #expect(form is MockEmailVerificationRequestForm)
    }

    @Test
    func `PhoneVerificationRequestForm conforms to Form`() {
        let form: any Form = MockPhoneVerificationRequestForm(phone: "+1234567890")
        #expect(form is MockPhoneVerificationRequestForm)
    }

    @Test
    func `EmailVerificationRequestForm has email property`() {
        let form = MockEmailVerificationRequestForm(email: "test@example.com")
        #expect(form.email == "test@example.com")
    }

    @Test
    func `PhoneVerificationRequestForm has phone property`() {
        let form = MockPhoneVerificationRequestForm(phone: "+1234567890")
        #expect(form.phone == "+1234567890")
    }

    // MARK: - VerificationConfirmForm Tests

    struct MockEmailVerificationConfirmForm: EmailVerificationConfirmForm {
        static func validations(_ validations: inout Validations) {
            validations.add("code", as: String.self, is: .count(6...20))
        }

        let code: String
        let email: String
    }

    struct MockPhoneVerificationConfirmForm: PhoneVerificationConfirmForm {
        static func validations(_ validations: inout Validations) {
            validations.add("code", as: String.self, is: .count(6...20))
        }

        let code: String
        let phone: String
    }

    @Test
    func `EmailVerificationConfirmForm conforms to VerificationConfirmForm`() {
        let form: any VerificationConfirmForm = MockEmailVerificationConfirmForm(code: "123456", email: "test@example.com")
        #expect(form is MockEmailVerificationConfirmForm)
    }

    @Test
    func `PhoneVerificationConfirmForm conforms to VerificationConfirmForm`() {
        let form: any VerificationConfirmForm = MockPhoneVerificationConfirmForm(code: "123456", phone: "+1234567890")
        #expect(form is MockPhoneVerificationConfirmForm)
    }

    @Test
    func `VerificationConfirmForm has code property`() {
        let form = MockEmailVerificationConfirmForm(code: "ABC123", email: "test@example.com")
        #expect(form.code == "ABC123")
    }

    // MARK: - Email Password Reset Forms Tests

    struct MockEmailPasswordResetRequestForm: EmailPasswordResetRequestForm {
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
        }

        let email: String
    }

    struct MockEmailPasswordResetVerifyForm: EmailPasswordResetVerifyForm {
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
            validations.add("code", as: String.self, is: .count(6...20))
            validations.add("newPassword", as: String.self, is: .count(6...))
        }

        let email: String
        let code: String
        let newPassword: String
    }

    struct MockEmailPasswordResetResendForm: EmailPasswordResetResendForm {
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String.self, is: .email)
        }

        let email: String
    }

    @Test
    func `EmailPasswordResetRequestForm conforms to Form`() {
        let form: any Form = MockEmailPasswordResetRequestForm(email: "test@example.com")
        #expect(form is MockEmailPasswordResetRequestForm)
    }

    @Test
    func `EmailPasswordResetVerifyForm has required properties`() {
        let form = MockEmailPasswordResetVerifyForm(
            email: "test@example.com",
            code: "123456",
            newPassword: "newpassword123"
        )

        #expect(form.email == "test@example.com")
        #expect(form.code == "123456")
        #expect(form.newPassword == "newpassword123")
    }

    @Test
    func `EmailPasswordResetResendForm has email property`() {
        let form = MockEmailPasswordResetResendForm(email: "test@example.com")
        #expect(form.email == "test@example.com")
    }

    // MARK: - Phone Password Reset Forms Tests

    struct MockPhonePasswordResetRequestForm: PhonePasswordResetRequestForm {
        static func validations(_ validations: inout Validations) {
            validations.add("phone", as: String.self, is: .count(6...))
        }

        let phone: String
    }

    struct MockPhonePasswordResetVerifyForm: PhonePasswordResetVerifyForm {
        static func validations(_ validations: inout Validations) {
            validations.add("phone", as: String.self, is: .count(6...))
            validations.add("code", as: String.self, is: .count(6...20))
            validations.add("newPassword", as: String.self, is: .count(6...))
        }

        let phone: String
        let code: String
        let newPassword: String
    }

    struct MockPhonePasswordResetResendForm: PhonePasswordResetResendForm {
        static func validations(_ validations: inout Validations) {
            validations.add("phone", as: String.self, is: .count(6...))
        }

        let phone: String
    }

    @Test
    func `PhonePasswordResetRequestForm conforms to Form`() {
        let form: any Form = MockPhonePasswordResetRequestForm(phone: "+1234567890")
        #expect(form is MockPhonePasswordResetRequestForm)
    }

    @Test
    func `PhonePasswordResetVerifyForm has required properties`() {
        let form = MockPhonePasswordResetVerifyForm(
            phone: "+1234567890",
            code: "123456",
            newPassword: "newpassword123"
        )

        #expect(form.phone == "+1234567890")
        #expect(form.code == "123456")
        #expect(form.newPassword == "newpassword123")
    }

    @Test
    func `PhonePasswordResetResendForm has phone property`() {
        let form = MockPhonePasswordResetResendForm(phone: "+1234567890")
        #expect(form.phone == "+1234567890")
    }

    // MARK: - Protocol Hierarchy Tests

    @Test
    func `All form protocols inherit from Form`() {
        let forms: [any Form] = [
            MockRefreshTokenForm(refreshToken: "token"),
            MockLogoutForm(),
            MockEmailVerificationRequestForm(email: "test@example.com"),
            MockPhoneVerificationRequestForm(phone: "+1234567890"),
            MockEmailVerificationConfirmForm(code: "123456", email: "test@example.com"),
            MockPhoneVerificationConfirmForm(code: "123456", phone: "+1234567890"),
            MockEmailPasswordResetRequestForm(email: "test@example.com"),
            MockPhonePasswordResetRequestForm(phone: "+1234567890")
        ]

        #expect(forms.count == 8)
        for form in forms {
            #expect(form is any Content)
            #expect(form is any Validatable)
        }
    }
}

import Testing
import Vapor
@testable import Passage

@Suite
struct `RegisterForm Protocol Tests` {

    // MARK: - Mock Implementation

    struct MockRegisterForm: RegisterForm {
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String?.self, is: .email || .nil, required: false)
            validations.add("password", as: String.self, is: .count(6...))
            validations.add("confirmPassword", as: String.self, is: .count(6...))
        }

        let email: String?
        let phone: String?
        let username: String?
        let password: String
        let confirmPassword: String

        func validate() throws {
            if password != confirmPassword {
                throw Abort(.badRequest, reason: "Passwords do not match")
            }
        }
    }

    // MARK: - asIdentifier() Tests

    @Test
    func `RegisterForm asIdentifier returns email identifier`() throws {
        let form = MockRegisterForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )

        let identifier = try form.asIdentifier()
        #expect(identifier.kind == .email)
        #expect(identifier.value == "test@example.com")
    }

    @Test
    func `RegisterForm asIdentifier returns phone identifier`() throws {
        let form = MockRegisterForm(
            email: nil,
            phone: "+1234567890",
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )

        let identifier = try form.asIdentifier()
        #expect(identifier.kind == .phone)
        #expect(identifier.value == "+1234567890")
    }

    @Test
    func `RegisterForm asIdentifier returns username identifier`() throws {
        let form = MockRegisterForm(
            email: nil,
            phone: nil,
            username: "johndoe",
            password: "password123",
            confirmPassword: "password123"
        )

        let identifier = try form.asIdentifier()
        #expect(identifier.kind == .username)
        #expect(identifier.value == "johndoe")
    }

    @Test
    func `RegisterForm asIdentifier prefers email over phone`() throws {
        let form = MockRegisterForm(
            email: "test@example.com",
            phone: "+1234567890",
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )

        let identifier = try form.asIdentifier()
        #expect(identifier.kind == .email)
        #expect(identifier.value == "test@example.com")
    }

    @Test
    func `RegisterForm asIdentifier throws when no identifier provided`() {
        let form = MockRegisterForm(
            email: nil,
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )

        #expect(throws: AuthenticationError.identifierNotSpecified) {
            _ = try form.asIdentifier()
        }
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `RegisterForm conforms to Form protocol`() {
        let form: any Form = MockRegisterForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )
        #expect(form is MockRegisterForm)
    }

    @Test
    func `RegisterForm has required properties`() {
        let form = MockRegisterForm(
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

    // MARK: - Password Validation Tests

    @Test
    func `RegisterForm validate succeeds when passwords match`() throws {
        let form = MockRegisterForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "password123"
        )

        try form.validate() // Should not throw
    }

    @Test
    func `RegisterForm validate throws when passwords don't match`() {
        let form = MockRegisterForm(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123",
            confirmPassword: "different_password"
        )

        #expect(throws: (any Error).self) {
            try form.validate()
        }
    }
}

import Testing
import Vapor
@testable import Passage

@Suite
struct `LoginForm Protocol Tests` {

    // MARK: - Mock Implementations

    struct MockLoginFormWithEmail: LoginForm {
        static func validations(_ validations: inout Validations) {
            validations.add("email", as: String?.self, is: .email || .nil, required: false)
            validations.add("password", as: String.self, is: .count(6...))
        }

        let email: String?
        let phone: String?
        let username: String?
        let password: String

        func validate() throws {
            // No additional validation
        }
    }

    struct MockLoginFormWithPhone: LoginForm {
        static func validations(_ validations: inout Validations) {
            validations.add("phone", as: String?.self, required: false)
            validations.add("password", as: String.self, is: .count(6...))
        }

        let email: String?
        let phone: String?
        let username: String?
        let password: String

        func validate() throws {
            // No additional validation
        }
    }

    struct MockLoginFormWithUsername: LoginForm {
        static func validations(_ validations: inout Validations) {
            validations.add("username", as: String?.self, required: false)
            validations.add("password", as: String.self, is: .count(6...))
        }

        let email: String?
        let phone: String?
        let username: String?
        let password: String

        func validate() throws {
            // No additional validation
        }
    }

    // MARK: - asIdentifier() Tests

    @Test
    func `LoginForm asIdentifier returns email identifier`() throws {
        let form = MockLoginFormWithEmail(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123"
        )

        let identifier = try form.asIdentifier()
        #expect(identifier.kind == .email)
        #expect(identifier.value == "test@example.com")
    }

    @Test
    func `LoginForm asIdentifier returns phone identifier`() throws {
        let form = MockLoginFormWithPhone(
            email: nil,
            phone: "+1234567890",
            username: nil,
            password: "password123"
        )

        let identifier = try form.asIdentifier()
        #expect(identifier.kind == .phone)
        #expect(identifier.value == "+1234567890")
    }

    @Test
    func `LoginForm asIdentifier returns username identifier`() throws {
        let form = MockLoginFormWithUsername(
            email: nil,
            phone: nil,
            username: "johndoe",
            password: "password123"
        )

        let identifier = try form.asIdentifier()
        #expect(identifier.kind == .username)
        #expect(identifier.value == "johndoe")
    }

    @Test
    func `LoginForm asIdentifier prefers email over phone`() throws {
        let form = MockLoginFormWithEmail(
            email: "test@example.com",
            phone: "+1234567890",
            username: nil,
            password: "password123"
        )

        let identifier = try form.asIdentifier()
        #expect(identifier.kind == .email)
        #expect(identifier.value == "test@example.com")
    }

    @Test
    func `LoginForm asIdentifier prefers email over username`() throws {
        let form = MockLoginFormWithEmail(
            email: "test@example.com",
            phone: nil,
            username: "johndoe",
            password: "password123"
        )

        let identifier = try form.asIdentifier()
        #expect(identifier.kind == .email)
        #expect(identifier.value == "test@example.com")
    }

    @Test
    func `LoginForm asIdentifier prefers phone over username`() throws {
        let form = MockLoginFormWithPhone(
            email: nil,
            phone: "+1234567890",
            username: "johndoe",
            password: "password123"
        )

        let identifier = try form.asIdentifier()
        #expect(identifier.kind == .phone)
        #expect(identifier.value == "+1234567890")
    }

    @Test
    func `LoginForm asIdentifier throws when no identifier provided`() {
        let form = MockLoginFormWithEmail(
            email: nil,
            phone: nil,
            username: nil,
            password: "password123"
        )

        #expect(throws: AuthenticationError.identifierNotSpecified) {
            _ = try form.asIdentifier()
        }
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `LoginForm conforms to Form protocol`() {
        let form: any Form = MockLoginFormWithEmail(
            email: "test@example.com",
            phone: nil,
            username: nil,
            password: "password123"
        )
        #expect(form is MockLoginFormWithEmail)
    }

    @Test
    func `LoginForm has required properties`() {
        let form = MockLoginFormWithEmail(
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
}

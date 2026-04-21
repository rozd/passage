import Testing
import Vapor
@testable import Passage

@Suite
struct `Form Protocol Tests` {

    // MARK: - Mock Implementation

    struct MockForm: Form {
        static func validations(_ validations: inout Validations) {
            validations.add("name", as: String.self, is: !.empty)
        }

        let name: String
    }

    struct MockFormWithValidation: Form {
        static func validations(_ validations: inout Validations) {
            validations.add("value", as: Int.self, is: .range(1...100))
        }

        let value: Int

        func validate() throws {
            if value < 10 {
                throw Abort(.badRequest, reason: "Value must be at least 10")
            }
        }
    }

    struct MockFormNoExtraValidation: Form {
        static func validations(_ validations: inout Validations) {
            validations.add("data", as: String.self, is: !.empty)
        }

        let data: String
        // No validate() override - uses default implementation
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `Form protocol can be implemented`() {
        let form = MockForm(name: "test")
        let _: any Form = form
        #expect(form.name == "test")
    }

    @Test
    func `Form protocol conforms to Content`() {
        let form = MockForm(name: "test")
        let _: any Content = form
        #expect(form is any Content)
    }

    @Test
    func `Form protocol conforms to Validatable`() {
        let form = MockForm(name: "test")
        let _: any Validatable = form
        #expect(form is any Validatable)
    }

    // MARK: - Default validate() Implementation Tests

    @Test
    func `Form default validate() does nothing`() throws {
        let form = MockFormNoExtraValidation(data: "test data")
        try form.validate() // Should not throw
    }

    // MARK: - Custom validate() Implementation Tests

    @Test
    func `Form custom validate() can throw errors`() {
        let form = MockFormWithValidation(value: 5)

        #expect(throws: (any Error).self) {
            try form.validate()
        }
    }

    @Test
    func `Form custom validate() succeeds when valid`() throws {
        let form = MockFormWithValidation(value: 50)
        try form.validate() // Should not throw
    }

    // MARK: - Multiple Form Implementations Tests

    @Test
    func `Multiple Form implementations can coexist`() {
        let form1: any Form = MockForm(name: "test1")
        let form2: any Form = MockFormWithValidation(value: 25)
        let form3: any Form = MockFormNoExtraValidation(data: "test3")

        #expect(form1 is MockForm)
        #expect(form2 is MockFormWithValidation)
        #expect(form3 is MockFormNoExtraValidation)
    }

    // MARK: - Form Properties Tests

    @Test
    func `Form can have properties`() {
        let form = MockForm(name: "test name")
        #expect(form.name == "test name")
    }

    @Test
    func `Form can have computed properties`() {
        struct FormWithComputed: Form {
            static func validations(_ validations: inout Validations) {}

            let firstName: String
            let lastName: String

            var fullName: String {
                "\(firstName) \(lastName)"
            }
        }

        let form = FormWithComputed(firstName: "John", lastName: "Doe")
        #expect(form.fullName == "John Doe")
    }
}

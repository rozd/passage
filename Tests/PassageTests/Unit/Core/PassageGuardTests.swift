import Testing
import Vapor
@testable import Passage

@Suite
struct `PassageGuard Tests` {

    // MARK: - Structure Tests

    @Test
    func `PassageGuard can be initialized with default error`() {
        let guard_ = PassageGuard()
        #expect(guard_ != nil)
    }

    @Test
    func `PassageGuard can be initialized with custom error`() {
        let customError = Abort(.forbidden, reason: "Custom forbidden error")
        let guard_ = PassageGuard(throwing: customError)
        #expect(guard_ != nil)
    }

    @Test
    func `PassageGuard type name is correct`() {
        let typeName = String(describing: PassageGuard.self)
        #expect(typeName == "PassageGuard")
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `PassageGuard conforms to AsyncMiddleware`() {
        let guard_ = PassageGuard()
        #expect(guard_ is any AsyncMiddleware)
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    /// If the type doesn't conform to Sendable, passing it to this function
    /// will cause a compile-time error.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `PassageGuard conforms to Sendable`() {
        assertSendable(PassageGuard())
        assertSendable(PassageGuard(throwing: Abort(.unauthorized)))
    }
}

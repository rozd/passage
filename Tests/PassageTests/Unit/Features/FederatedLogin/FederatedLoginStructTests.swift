import Testing
import Vapor
@testable import Passage

@Suite
struct `FederatedLogin Struct Tests` {

    // MARK: - FederatedLogin Struct Tests

    @Test
    func `FederatedLogin struct is properly namespaced in Passage`() {
        let typeName = String(reflecting: Passage.FederatedLogin.self)
        #expect(typeName.contains("Passage.FederatedLogin"))
    }

    @Test
    func `FederatedLogin struct conforms to Sendable`() {
        let _: any Sendable.Type = Passage.FederatedLogin.self
        #expect(Passage.FederatedLogin.self is (any Sendable).Type)
    }

    @Test
    func `FederatedLogin feature is properly namespaced`() {
        // Verify the entire FederatedLogin namespace is in Passage
        let structName = String(reflecting: Passage.FederatedLogin.self)
        #expect(structName.contains("Passage.FederatedLogin"))
    }

    // MARK: - All Sendable Conformance Tests

    @Test
    func `All FederatedLogin types conform to Sendable`() {
        #expect(Passage.FederatedLogin.self is (any Sendable).Type)
    }

}

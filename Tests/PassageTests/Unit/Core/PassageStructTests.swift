import Testing
import Vapor
@testable import Passage

@Suite
struct `Passage Struct Tests` {

    // MARK: - Passage Struct Tests

    @Test
    func `Passage struct is properly namespaced`() {
        let typeName = String(reflecting: Passage.self)
        #expect(typeName.contains("Passage"))
    }

    @Test
    func `Passage struct conforms to Sendable`() {
        #expect(Passage.self is any Sendable.Type)
    }

    // MARK: - Storage Nested Type Tests

    @Test
    func `Storage is nested within Passage`() {
        let typeName = String(reflecting: Passage.Storage.self)
        #expect(typeName.contains("Passage.Storage"))
    }

    @Test
    func `Storage.Key is nested within Storage`() {
        let typeName = String(reflecting: Passage.Storage.Key.self)
        #expect(typeName.contains("Passage.Storage.Key"))
    }

    @Test
    func `Storage.Key conforms to StorageKey protocol`() {
        #expect(Passage.Storage.Key.self is any StorageKey.Type)
    }

    @Test
    func `Storage.Key.Value is Storage type`() {
        let valueType = Passage.Storage.Key.Value.self
        #expect(valueType == Passage.Storage.self)
    }
}

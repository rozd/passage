import Testing
@testable import Passage

@Suite
struct `Sessions Configuration Tests` {

    // MARK: - Initialization Tests

    @Test
    func `Sessions configuration initializes with default values`() {
        let session = Passage.Configuration.Sessions()

        #expect(session.enabled == false)
    }

    @Test
    func `Sessions configuration initializes with enabled true`() {
        let session = Passage.Configuration.Sessions(enabled: true)

        #expect(session.enabled == true)
    }

    @Test
    func `Sessions configuration initializes with enabled false`() {
        let session = Passage.Configuration.Sessions(enabled: false)

        #expect(session.enabled == false)
    }

    // MARK: - Protocol Conformance Tests

    @Test
    func `Sessions configuration conforms to Sendable`() {
        func acceptsSendable<T: Sendable>(_ type: T.Type) {}
        acceptsSendable(Passage.Configuration.Sessions.self)
    }

    // MARK: - Type Tests

    @Test
    func `Sessions configuration type name is correct`() {
        let typeName = String(describing: Passage.Configuration.Sessions.self)
        #expect(typeName == "Sessions")
    }
}

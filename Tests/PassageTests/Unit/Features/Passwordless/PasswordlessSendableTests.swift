import Testing
import Vapor
@testable import Passage

@Suite
struct `Passwordless Sendable Conformance Tests` {

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    // MARK: - Route Collection Tests

    @Test
    func `Passwordless.MagicLinkEmailRouteCollection conforms to Sendable`() {
        let routes = Passage.Configuration.Passwordless.MagicLink.Routes.email
        assertSendable(Passage.Passwordless.MagicLinkEmailRouteCollection(routes: routes, group: []))
    }

    // MARK: - Job Payload Tests

    @Test
    func `Passwordless.EmailMagicLinkPayload conforms to Sendable`() {
        assertSendable(Passage.Passwordless.EmailMagicLinkPayload(
            email: "test@example.com",
            userId: "user123",
            magicLinkURL: URL(string: "https://example.com/magic")!
        ))
    }

    @Test
    func `Passwordless.SendEmailMagicLinkJob conforms to Sendable`() {
        assertSendable(Passage.Passwordless.SendEmailMagicLinkJob())
    }
}

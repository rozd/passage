import Foundation
import Testing
@testable import Passage

// MARK: - AAL1 per-account failed-attempt cap
//
// SP 800-63B §5.2.2-b: Unless otherwise specified in the description of a
// given authenticator, the verifier SHALL limit consecutive failed
// authentication attempts on a single account to no more than 100. Passage
// enforces this via the per-identifier throttle rule. The shipped default is
// stricter than the spec requires (10), but the invariant that protects
// §5.2.2-b is the *ceiling* — any future loosening of `perIdentifier` must
// not exceed 100.

@Suite("AAL1 per-account cap", .tags(.aal1, .throttling))
struct PerAccountCapTests {

    @Test(
        "§5.2.2-b: Per-account throttle ceiling is at most 100 consecutive failed attempts",
        .tags(.aal1, .throttling, .authenticator, .unit, .shall)
    )
    func perAccountCapIsAtMost100() async throws {
        // §5.2.2-b caps failed attempts at 100; Passage's shipped default is
        // 10 — well inside the budget. The test pins the *ceiling*: if the
        // default is ever raised above 100, §5.2.2-b is violated.
        let login = Passage.Configuration.Throttle.Login()
        #expect(login.perIdentifier.maxFailures <= 100,
                "per-account failed-attempt cap must be ≤ 100 to satisfy §5.2.2-b")
        #expect(login.perIdentifier.maxFailures > 0,
                "per-account throttle must actually be engaged (maxFailures > 0)")
    }
}

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

    @Test(
        "§5.2.2-c: Successful authentication disregards prior failed attempts on the same bucket",
        .tags(.aal1, .throttling, .authenticator, .unit, .should)
    )
    func successfulAuthResetsBucket() async throws {
        // Exercise the concrete reset path on the shipped in-memory throttle.
        // After a run of failures puts the bucket into a throttled state,
        // calling `reset(bucket:)` — which `LoginThrottleMiddleware` invokes
        // on a 2xx response — must return the bucket to `.allowed`. That is
        // the library-side behaviour §5.2.2-c expects of the verifier when
        // the subscriber successfully authenticates.
        let service = Passage.Throttle.InMemoryService()
        let rule = Passage.Throttle.Rule(maxFailures: 3, window: 60)
        let bucket = Passage.Throttle.Bucket(
            scope: .login,
            dimension: .source("198.51.100.7"),
            enabled: true
        )
        let t0 = Date()

        for i in 0..<4 {
            await service.penalize(bucket: bucket, at: t0.addingTimeInterval(Double(i)))
        }

        // Precondition: bucket is now throttled.
        let before = await service.check(bucket: bucket, against: rule, at: t0.addingTimeInterval(4))
        guard case .throttled = before else {
            Issue.record("precondition failed: bucket must be throttled before reset, got \(before)")
            return
        }

        // §5.2.2-c: a successful auth SHOULD disregard the history.
        await service.reset(bucket: bucket)

        let after = await service.check(bucket: bucket, against: rule, at: t0.addingTimeInterval(4))
        #expect(after == .allowed,
                "after reset (mirroring the success path §5.2.2-c), the bucket must be allowed again")
    }
}

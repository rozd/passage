import Foundation
import Testing
@testable import Passage

// MARK: - AAL1 no arbitrary password rotation
//
// SP 800-63B §5.1.1.2-s: Verifiers SHOULD NOT require memorized secrets to be
// changed arbitrarily (e.g., periodically). Passage enforces this
// structurally by not exposing a password-age / rotation-interval knob on
// the PasswordPolicy — Mirror-reflecting the policy is a compile-agnostic
// way to assert no such field has crept in.

@Suite("AAL1 no arbitrary password rotation", .tags(.aal1, .memorizedSecret))
struct PasswordRotationTests {

    @Test(
        "§5.1.1.2-s: PasswordPolicy exposes no password-age / rotation-interval field",
        .tags(.aal1, .memorizedSecret, .authenticator, .unit, .should)
    )
    func noPasswordRotationPolicyField() async throws {
        // Reflect the default policy and assert no field name hints at a
        // time-based rotation requirement. Using Mirror keeps the test
        // honest if the API shape changes — any future `expirationInterval`,
        // `maxAge`, or `rotationPeriod` addition will trip the assertion.
        let policy = Passage.Configuration.PasswordPolicy.relaxed()
        let mirror = Mirror(reflecting: policy)

        let forbiddenSubstrings = ["age", "rotation", "expir", "lifetime"]
        for child in mirror.children {
            let label = child.label?.lowercased() ?? ""
            for forbidden in forbiddenSubstrings {
                #expect(!label.contains(forbidden),
                        "PasswordPolicy.\(label) hints at arbitrary rotation — §5.1.1.2-s SHOULD NOT impose one")
            }
        }

        // Positive anchor: the fields we *do* expect exist, so the Mirror
        // walk itself is non-vacuous. If the struct is gutted and every
        // child disappears, the forbidden loop becomes a false negative —
        // this anchor catches that.
        let labels = Set(mirror.children.compactMap { $0.label })
        #expect(labels.contains("minLength"),
                "PasswordPolicy must still expose minLength (anchor for the mirror walk)")
    }
}

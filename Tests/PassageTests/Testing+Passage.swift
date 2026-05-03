import Testing

extension Tag {
    @Tag static var unit: Self
    @Tag static var security: Self
    @Tag static var integration: Self
}

extension Tag {
    @Tag static var login: Self
    @Tag static var register: Self
    @Tag static var verifyEmail: Self
    @Tag static var verifyPhone: Self
    @Tag static var resetPassword: Self
    @Tag static var federatedLogin: Self
    @Tag static var passwordless: Self
    @Tag static var exchangeCode: Self
    @Tag static var passkey: Self
    @Tag static var hooks: Self
}

// MARK: - NIST SP 800-63B AAL1 tags
//
// Tags below support the AAL1 conformance test suite under Tests/PassageTests/AAL1/.
// See docs/AAL1/README.md for the workflow and docs/AAL1/requirements.yaml for the
// clause ledger. Section-level tags mirror the structure of SP 800-63B rev 3;
// normative-level tags (shall / shallNot / should) allow filtering by requirement
// strength, e.g. `swift test --filter tag:shall`.

extension Tag {
    // Assurance level
    @Tag static var aal1: Self

    // Section-level (mirrors SP 800-63B rev 3 structure)
    @Tag static var authenticator: Self         // § 5
    @Tag static var memorizedSecret: Self       // § 5.1.1
    @Tag static var throttling: Self            // § 5.2.2
    @Tag static var sessionManagement: Self     // § 7
    @Tag static var reauthentication: Self      // § 4.1.3
    @Tag static var recordsRetention: Self      // § 4.4

    // Normative level
    @Tag static var shall: Self
    @Tag static var shallNot: Self
    @Tag static var should: Self
}

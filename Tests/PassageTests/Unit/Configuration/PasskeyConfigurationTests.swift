import Testing
import Foundation
import Vapor
@testable import Passage

/// Coverage for `Configuration.Passkey` and its nested `Policy`, `Routes`, and
/// `Linking` structs. These values drive the runtime behavior of the Passkey
/// feature — initializer defaults, option forwarding, route path composition,
/// and explicit enablement via `Passage.Configuration.passkey`.
@Suite("Passkey Configuration Tests", .tags(.unit))
struct PasskeyConfigurationTests {

    // MARK: - Top-level values

    @Test("Passkey initialization with explicit values")
    func configExplicit() {
        let config = Passage.Configuration.Passkey(
            policy: .init(userVerification: .required),
            challengeTTL: 600
        )
        #expect(config.challengeTTL == 600)
        #expect(config.policy.userVerification == .required)
    }

    @Test("challengeTTL defaults to 300 seconds")
    func configChallengeTTLDefault() {
        let config = Passage.Configuration.Passkey()
        #expect(config.challengeTTL == 300)
    }

    @Test("policy defaults to Policy.init()")
    func configPolicyDefault() {
        let config = Passage.Configuration.Passkey()
        #expect(config.policy.userVerification == .preferred)
        #expect(config.policy.attestation == .none)
        #expect(config.policy.supportedAlgorithms == [.ES256, .RS256])
    }

    // MARK: - Policy

    @Test("Policy defaults match WebAuthn recommended settings")
    func policyDefaults() {
        let policy = Passage.Configuration.Passkey.Policy()
        #expect(policy.timeout == nil)
        #expect(policy.attestation == .none)
        #expect(policy.userVerification == .preferred)
        #expect(policy.supportedAlgorithms == [.ES256, .RS256])
        #expect(policy.allowDiscoverableLogin == true)
    }

    @Test("Policy with all fields customized")
    func policyCustomized() {
        let policy = Passage.Configuration.Passkey.Policy(
            timeout: .seconds(90),
            attestation: .direct,
            userVerification: .required,
            supportedAlgorithms: [.ES256, .EdDSA],
            allowDiscoverableLogin: false
        )
        #expect(policy.timeout == .seconds(90))
        #expect(policy.attestation == .direct)
        #expect(policy.userVerification == .required)
        #expect(policy.supportedAlgorithms == [.ES256, .EdDSA])
        #expect(policy.allowDiscoverableLogin == false)
    }

    // MARK: - Routes

    @Test("Routes defaults: group=passkey, signup and register both have [begin]/[finish]")
    func routesDefaults() {
        let routes = Passage.Configuration.Passkey.Routes()
        #expect(routes.group.map { $0.description } == ["passkey"])
        #expect(routes.signupBegin.path.map { $0.description } == ["signup", "begin"])
        #expect(routes.signupFinish.path.map { $0.description } == ["signup", "finish"])
        #expect(routes.registerBegin.path.map { $0.description } == ["register", "begin"])
        #expect(routes.registerFinish.path.map { $0.description } == ["register", "finish"])
        #expect(routes.authenticateBegin.path.map { $0.description } == ["authenticate", "begin"])
        #expect(routes.authenticateFinish.path.map { $0.description } == ["authenticate", "finish"])
    }

    @Test("Routes custom group and paths")
    func routesCustom() {
        let routes = Passage.Configuration.Passkey.Routes(
            group: ["pk"],
            signupBegin: .init(path: "start"),
            signupFinish: .init(path: "done"),
            registerBegin: .init(path: "add-start"),
            registerFinish: .init(path: "add-done")
        )
        #expect(routes.group.map { $0.description } == ["pk"])
        #expect(routes.signupBegin.path.map { $0.description } == ["start"])
        #expect(routes.signupFinish.path.map { $0.description } == ["done"])
        #expect(routes.registerBegin.path.map { $0.description } == ["add-start"])
        #expect(routes.registerFinish.path.map { $0.description } == ["add-done"])
    }

    @Test("Composed paths include group prefix for signup, register, and authenticate")
    func routesComposedPaths() {
        let routes = Passage.Configuration.Passkey.Routes(
            group: ["pk"],
            signupBegin: .init(path: "s-begin"),
            signupFinish: .init(path: "s-finish"),
            registerBegin: .init(path: "r-begin"),
            registerFinish: .init(path: "r-finish"),
            authenticateBegin: .init(path: "a-begin"),
            authenticateFinish: .init(path: "a-finish")
        )
        #expect(routes.signupBeginPath.map { $0.description } == ["pk", "s-begin"])
        #expect(routes.signupFinishPath.map { $0.description } == ["pk", "s-finish"])
        #expect(routes.registerBeginPath.map { $0.description } == ["pk", "r-begin"])
        #expect(routes.registerFinishPath.map { $0.description } == ["pk", "r-finish"])
        #expect(routes.authenticateBeginPath.map { $0.description } == ["pk", "a-begin"])
        #expect(routes.authenticateFinishPath.map { $0.description } == ["pk", "a-finish"])
    }

    // MARK: - Linking

    @Test("Linking.allowAutoRegistration defaults to true")
    func linkingDefaults() {
        let linking = Passage.Configuration.Passkey.Linking()
        #expect(linking.allowAutoRegistration == true)
    }

    @Test("Linking can disable auto-registration")
    func linkingDisabled() {
        let linking = Passage.Configuration.Passkey.Linking(allowAutoRegistration: false)
        #expect(linking.allowAutoRegistration == false)
    }

    // MARK: - Passkey aggregate

    @Test("Configuration.Passkey initialization composes nested values")
    func passkeyComposition() {
        let passkey = Passage.Configuration.Passkey(
            routes: .init(group: ["custom"]),
            linking: .init(allowAutoRegistration: false),
            challengeTTL: 60
        )
        #expect(passkey.routes.group.map { $0.description } == ["custom"])
        #expect(passkey.challengeTTL == 60)
        #expect(passkey.linking.allowAutoRegistration == false)
    }

    // MARK: - Root Configuration

    @Test("Configuration.passkey defaults to Passkey.init()")
    func rootConfigurationPasskeyDefaults() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )
        #expect(config.passkey.challengeTTL == 300)
    }

    @Test("Configuration.passkey round-trips through the initializer")
    func rootConfigurationPasskeySet() throws {
        let passkey = Passage.Configuration.Passkey(challengeTTL: 42)
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}")),
            passkey: passkey
        )
        #expect(config.passkey.challengeTTL == 42)
    }

    // MARK: - Sendable

    @Test("Every configuration struct is Sendable")
    func allAreSendable() {
        let _: any Sendable = Passage.Configuration.Passkey.Routes()
        let _: any Sendable = Passage.Configuration.Passkey.Policy()
        let _: any Sendable = Passage.Configuration.Passkey.Linking()
        let _: any Sendable = Passage.Configuration.Passkey()
        #expect(Bool(true))
    }
}

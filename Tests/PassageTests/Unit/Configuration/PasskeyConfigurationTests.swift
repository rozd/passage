import Testing
import Foundation
import Vapor
@testable import Passage

/// Coverage for `Configuration.Passkey` and its nested `Policy`, `Routes`, and
/// `Linking` structs. These values drive the runtime behavior of the Passkey
/// feature — initializer defaults, option forwarding, route path composition,
/// and explicit enablement via `Passage.Configuration.passkey`.
@Suite(.tags(.unit))
struct `Passkey Configuration Tests` {

    // MARK: - Top-level values

    @Test
    func `Passkey initialization with explicit values`() {
        let config = Passage.Configuration.Passkey(
            policy: .init(userVerification: .required),
            challengeTTL: 600
        )
        #expect(config.challengeTTL == 600)
        #expect(config.policy.userVerification == .required)
    }

    @Test
    func `challengeTTL defaults to 300 seconds`() {
        let config = Passage.Configuration.Passkey()
        #expect(config.challengeTTL == 300)
    }

    @Test
    func `policy defaults to Policy.init()`() {
        let config = Passage.Configuration.Passkey()
        #expect(config.policy.userVerification == .preferred)
        #expect(config.policy.attestation == .none)
        #expect(config.policy.supportedAlgorithms == [.ES256, .RS256])
    }

    // MARK: - Policy

    @Test
    func `Policy defaults match WebAuthn recommended settings`() {
        let policy = Passage.Configuration.Passkey.Policy()
        #expect(policy.timeout == nil)
        #expect(policy.attestation == .none)
        #expect(policy.userVerification == .preferred)
        #expect(policy.supportedAlgorithms == [.ES256, .RS256])
        #expect(policy.allowDiscoverableLogin == true)
    }

    @Test
    func `Policy with all fields customized`() {
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

    @Test
    func `Routes defaults: guestRegistration is opt-in (nil); registration and authentication keep [begin]/[finish]`() {
        let routes = Passage.Configuration.Passkey.Routes()
        #expect(routes.group.map { $0.description } == ["passkey"])
        #expect(routes.guestRegistrationBegin == nil)
        #expect(routes.guestRegistrationFinish == nil)
        #expect(routes.registrationBegin.path.map { $0.description } == ["registration", "begin"])
        #expect(routes.registrationFinish.path.map { $0.description } == ["registration", "finish"])
        #expect(routes.authenticationBegin.path.map { $0.description } == ["authentication", "begin"])
        #expect(routes.authenticationFinish.path.map { $0.description } == ["authentication", "finish"])
    }

    @Test
    func `Composed guestRegistration paths are nil when guestRegistration is disabled (default)`() {
        let routes = Passage.Configuration.Passkey.Routes()
        #expect(routes.guestRegistrationBeginPath == nil)
        #expect(routes.guestRegistrationFinishPath == nil)
    }

    @Test
    func `Composed guestRegistration paths are nil when only one side is set`() {
        let onlyBegin = Passage.Configuration.Passkey.Routes(guestRegistrationBegin: .default)
        #expect(onlyBegin.guestRegistrationBeginPath?.map { $0.description } == ["passkey", "guest", "registration", "begin"])
        #expect(onlyBegin.guestRegistrationFinishPath == nil)

        let onlyFinish = Passage.Configuration.Passkey.Routes(guestRegistrationFinish: .default)
        #expect(onlyFinish.guestRegistrationBeginPath == nil)
        #expect(onlyFinish.guestRegistrationFinishPath?.map { $0.description } == ["passkey", "guest", "registration", "finish"])
    }

    @Test
    func `Routes opt-in: guestRegistration enabled via .default uses [guestRegistration]/[begin] and [guestRegistration]/[finish]`() {
        let routes = Passage.Configuration.Passkey.Routes(
            guestRegistrationBegin: .default,
            guestRegistrationFinish: .default
        )
        #expect(routes.guestRegistrationBegin?.path.map { $0.description } == ["guest", "registration", "begin"])
        #expect(routes.guestRegistrationFinish?.path.map { $0.description } == ["guest", "registration", "finish"])
        #expect(routes.guestRegistrationBeginPath?.map { $0.description } == ["passkey", "guest", "registration", "begin"])
        #expect(routes.guestRegistrationFinishPath?.map { $0.description } == ["passkey", "guest", "registration", "finish"])
    }

    @Test
    func `Routes custom group and paths`() {
        let routes = Passage.Configuration.Passkey.Routes(
            group: ["pk"],
            guestRegistrationBegin: .init(path: "start"),
            guestRegistrationFinish: .init(path: "done"),
            registrationBegin: .init(path: "add-start"),
            registrationFinish: .init(path: "add-done")
        )
        #expect(routes.group.map { $0.description } == ["pk"])
        #expect(routes.guestRegistrationBegin?.path.map { $0.description } == ["start"])
        #expect(routes.guestRegistrationFinish?.path.map { $0.description } == ["done"])
        #expect(routes.registrationBegin.path.map { $0.description } == ["add-start"])
        #expect(routes.registrationFinish.path.map { $0.description } == ["add-done"])
    }

    @Test
    func `Composed paths include group prefix for guestRegistration, registration, and authentication`() {
        let routes = Passage.Configuration.Passkey.Routes(
            group: ["pk"],
            guestRegistrationBegin: .init(path: "s-begin"),
            guestRegistrationFinish: .init(path: "s-finish"),
            registrationBegin: .init(path: "r-begin"),
            registrationFinish: .init(path: "r-finish"),
            authenticationBegin: .init(path: "a-begin"),
            authenticationFinish: .init(path: "a-finish")
        )
        #expect(routes.guestRegistrationBeginPath?.map { $0.description } == ["pk", "s-begin"])
        #expect(routes.guestRegistrationFinishPath?.map { $0.description } == ["pk", "s-finish"])
        #expect(routes.registrationBeginPath.map { $0.description } == ["pk", "r-begin"])
        #expect(routes.registrationFinishPath.map { $0.description } == ["pk", "r-finish"])
        #expect(routes.authenticationBeginPath.map { $0.description } == ["pk", "a-begin"])
        #expect(routes.authenticationFinishPath.map { $0.description } == ["pk", "a-finish"])
    }

    // MARK: - Linking

    @Test
    func `Linking.allowAutoRegistration defaults to true`() {
        let linking = Passage.Configuration.Passkey.Linking()
        #expect(linking.allowAutoRegistration == true)
    }

    @Test
    func `Linking can disable auto-registration`() {
        let linking = Passage.Configuration.Passkey.Linking(allowAutoRegistration: false)
        #expect(linking.allowAutoRegistration == false)
    }

    // MARK: - Passkey aggregate

    @Test
    func `Configuration.Passkey initialization composes nested values`() {
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

    @Test
    func `Configuration.passkey defaults to Passkey.init()`() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )
        #expect(config.passkey.challengeTTL == 300)
    }

    @Test
    func `Configuration.passkey round-trips through the initializer`() throws {
        let passkey = Passage.Configuration.Passkey(challengeTTL: 42)
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}")),
            passkey: passkey
        )
        #expect(config.passkey.challengeTTL == 42)
    }

    // MARK: - Sendable

    @Test
    func `Every configuration struct is Sendable`() {
        let _: any Sendable = Passage.Configuration.Passkey.Routes()
        let _: any Sendable = Passage.Configuration.Passkey.Policy()
        let _: any Sendable = Passage.Configuration.Passkey.Linking()
        let _: any Sendable = Passage.Configuration.Passkey()
        #expect(Bool(true))
    }
}

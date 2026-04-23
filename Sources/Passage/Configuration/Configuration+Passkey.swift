public import Foundation
public import Vapor

public extension Passage.Configuration {

    struct Passkey: Sendable {
        public let routes: Routes
        public let policy: Policy
        public let linking: Linking
        public let challengeTTL: TimeInterval

        public init(
            routes: Routes = .init(),
            policy: Policy = .init(),
            linking: Linking = .init(),
            challengeTTL: TimeInterval = 300.0,
        ) {
            self.routes = routes
            self.policy = policy
            self.linking = linking
            self.challengeTTL = challengeTTL
        }

        public struct Routes: Sendable {
            public struct SignupBegin: Sendable {
                public static let `default` = SignupBegin(path: "signup", "begin")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public struct SignupFinish: Sendable {
                public static let `default` = SignupFinish(path: "signup", "finish")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public struct RegisterBegin: Sendable {
                public static let `default` = RegisterBegin(path: "register", "begin")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public struct RegisterFinish: Sendable {
                public static let `default` = RegisterFinish(path: "register", "finish")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public struct AuthenticateBegin: Sendable {
                public static let `default` = AuthenticateBegin(path: "authenticate", "begin")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public struct AuthenticateFinish: Sendable {
                public static let `default` = AuthenticateFinish(path: "authenticate", "finish")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public let group: [PathComponent]
            public let signupBegin: SignupBegin?
            public let signupFinish: SignupFinish?
            public let registerBegin: RegisterBegin
            public let registerFinish: RegisterFinish
            public let authenticateBegin: AuthenticateBegin
            public let authenticateFinish: AuthenticateFinish

            public init(
                group: [PathComponent] = ["passkey"],
                signupBegin: SignupBegin? = nil,
                signupFinish: SignupFinish? = nil,
                registerBegin: RegisterBegin = .default,
                registerFinish: RegisterFinish = .default,
                authenticateBegin: AuthenticateBegin = .default,
                authenticateFinish: AuthenticateFinish = .default,
            ) {
                self.group = group
                self.signupBegin = signupBegin
                self.signupFinish = signupFinish
                self.registerBegin = registerBegin
                self.registerFinish = registerFinish
                self.authenticateBegin = authenticateBegin
                self.authenticateFinish = authenticateFinish
            }
        }

        /// Values forwarded verbatim to the service implementation.
        /// Lives here (not on PasskeyService) so apps can tune per-route
        /// behavior without touching the service.
        public struct Policy: Sendable {
            public let timeout: Duration?
            public let attestation: AttestationConveyancePreference
            public let userVerification: UserVerificationRequirement
            public let supportedAlgorithms: [COSEAlgorithmIdentifier]
            public let allowDiscoverableLogin: Bool

            public init(
                timeout: Duration? = nil,
                attestation: AttestationConveyancePreference = .none,
                userVerification: UserVerificationRequirement = .preferred,
                supportedAlgorithms: [COSEAlgorithmIdentifier] = [.ES256, .RS256],
                allowDiscoverableLogin: Bool = true,
            ) {
                self.timeout = timeout
                self.attestation = attestation
                self.userVerification = userVerification
                self.supportedAlgorithms = supportedAlgorithms
                self.allowDiscoverableLogin = allowDiscoverableLogin
            }
        }

        public struct Linking: Sendable {
            // Controls whether a passkey authentication that resolves to no user
            // is allowed to create one (analogue of AccountLinking for OAuth).
            public let allowAutoRegistration: Bool

            public init(
                allowAutoRegistration: Bool = true,
            ) {
                self.allowAutoRegistration = allowAutoRegistration
            }
        }
    }
}

// MARK: -

extension Passage.Configuration.Passkey.Routes {
    var signupBeginPath: [PathComponent]? {
        guard let path = signupBegin?.path else {
            return nil
        }
        return group + path
    }

    var signupFinishPath: [PathComponent]? {
        guard let path = signupFinish?.path else {
            return nil
        }
        return group + path
    }

    var registerBeginPath: [PathComponent] {
        return group + registerBegin.path
    }

    var registerFinishPath: [PathComponent] {
        return group + registerFinish.path
    }

    var authenticateBeginPath: [PathComponent] {
        return group + authenticateBegin.path
    }

    var authenticateFinishPath: [PathComponent] {
        return group + authenticateFinish.path
    }
}

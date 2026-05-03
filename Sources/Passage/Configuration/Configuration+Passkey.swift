public import Foundation
public import Vapor

extension Passage.Configuration {

    public struct Passkey: Sendable {
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
            public struct GuestRegistrationBegin: Sendable {
                public static let `default` = GuestRegistrationBegin(path: "guest", "registration", "begin")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public struct GuestRegistrationFinish: Sendable {
                public static let `default` = GuestRegistrationFinish(path: "guest", "registration", "finish")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public struct RegistrationBegin: Sendable {
                public static let `default` = RegistrationBegin(path: "registration", "begin")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public struct RegistrationFinish: Sendable {
                public static let `default` = RegistrationFinish(path: "registration", "finish")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public struct AuthenticationBegin: Sendable {
                public static let `default` = AuthenticationBegin(path: "authentication", "begin")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public struct AuthenticationFinish: Sendable {
                public static let `default` = AuthenticationFinish(path: "authentication", "finish")
                let path: [PathComponent]
                public init(path: PathComponent...) {
                    self.path = path
                }
            }

            public let group: [PathComponent]
            public let guestRegistrationBegin: GuestRegistrationBegin?
            public let guestRegistrationFinish: GuestRegistrationFinish?
            public let registrationBegin: RegistrationBegin
            public let registrationFinish: RegistrationFinish
            public let authenticationBegin: AuthenticationBegin
            public let authenticationFinish: AuthenticationFinish

            public init(
                group: [PathComponent] = ["passkey"],
                guestRegistrationBegin: GuestRegistrationBegin? = nil,
                guestRegistrationFinish: GuestRegistrationFinish? = nil,
                registrationBegin: RegistrationBegin = .default,
                registrationFinish: RegistrationFinish = .default,
                authenticationBegin: AuthenticationBegin = .default,
                authenticationFinish: AuthenticationFinish = .default,
            ) {
                self.group = group
                self.guestRegistrationBegin = guestRegistrationBegin
                self.guestRegistrationFinish = guestRegistrationFinish
                self.registrationBegin = registrationBegin
                self.registrationFinish = registrationFinish
                self.authenticationBegin = authenticationBegin
                self.authenticationFinish = authenticationFinish
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
    var guestRegistrationBeginPath: [PathComponent]? {
        guard let path = guestRegistrationBegin?.path else {
            return nil
        }
        return group + path
    }

    var guestRegistrationFinishPath: [PathComponent]? {
        guard let path = guestRegistrationFinish?.path else {
            return nil
        }
        return group + path
    }

    var registrationBeginPath: [PathComponent] {
        return group + registrationBegin.path
    }

    var registrationFinishPath: [PathComponent] {
        return group + registrationFinish.path
    }

    var authenticationBeginPath: [PathComponent] {
        return group + authenticationBegin.path
    }

    var authenticationFinishPath: [PathComponent] {
        return group + authenticationFinish.path
    }
}

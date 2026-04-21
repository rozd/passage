public import Foundation
public import Vapor

// MARK: - Restoration Configuration (Password Reset)

public extension Passage.Configuration {

    struct Restoration: Sendable {

        let preferredDelivery: Passage.DeliveryType
        let email: Email
        let phone: Phone
        let useQueues: Bool

        public init(
            preferredDelivery: Passage.DeliveryType = .email,
            email: Email = .init(),
            phone: Phone = .init(),
            useQueues: Bool = false
        ) {
            self.preferredDelivery = preferredDelivery
            self.email = email
            self.phone = phone
            self.useQueues = useQueues
        }
    }

}

// MARK: - Restoration by Email Configuration

extension Passage.Configuration.Restoration {

    public struct Email: Sendable {
        let routes: Routes
        let codeLength: Int
        let codeExpiration: TimeInterval
        let maxAttempts: Int

        public init(
            routes: Routes = .init(),
            codeLength: Int = 6,
            codeExpiration: TimeInterval = 15 * 60,  // 15 minutes
            maxAttempts: Int = 3,
        ) {
            self.routes = routes
            self.codeLength = codeLength
            self.codeExpiration = codeExpiration
            self.maxAttempts = maxAttempts
        }
    }

}

// MARK: Email Restoration Routes

public extension Passage.Configuration.Restoration.Email {

    struct Routes: Sendable {

        public struct Request: Sendable {
            public static let `default` = Request(path: "password", "reset", "email")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct Verify: Sendable {
            public static let `default` = Verify(path: "password", "reset", "email", "verify")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct Resend: Sendable {
            public static let `default` = Resend(path: "password", "reset", "email", "resend")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        let request: Request
        let verify: Verify
        let resend: Resend

        public init(
            request: Request = .default,
            verify: Verify = .default,
            resend: Resend = .default
        ) {
            self.request = request
            self.verify = verify
            self.resend = resend
        }
    }

}

// MARK: Email Restoration URLs

extension Passage.Configuration {

    var emailPasswordResetURL: URL {
        origin.appending(path: (routes.group + restoration.email.routes.verify.path).string)
    }

    /// Constructs the email password reset link URL with the given code and email as query parameters.
    func emailPasswordResetLinkURL(code: String, email: String) -> URL {
        return emailPasswordResetURL.appending(queryItems: [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "email", value: email)
        ])
    }

}

// MARK: - Restoration by Phone Configuration

public extension Passage.Configuration.Restoration {

    struct Phone: Sendable {
        let routes: Routes
        let codeLength: Int
        let codeExpiration: TimeInterval
        let maxAttempts: Int

        public init(
            routes: Routes = .init(),
            codeLength: Int = 6,
            codeExpiration: TimeInterval = 5 * 60,  // 5 minutes for SMS
            maxAttempts: Int = 3
        ) {
            self.routes = routes
            self.codeLength = codeLength
            self.codeExpiration = codeExpiration
            self.maxAttempts = maxAttempts
        }
    }

}

// MARK: Phone Restoration Routes

public extension Passage.Configuration.Restoration.Phone {

    struct Routes: Sendable {

        public struct Request: Sendable {
            public static let `default` = Request(path: "password", "reset", "phone")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct Verify: Sendable {
            public static let `default` = Verify(path: "password", "reset", "phone", "verify")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct Resend: Sendable {
            public static let `default` = Resend(path: "password", "reset", "phone", "resend")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        let request: Request
        let verify: Verify
        let resend: Resend

        public init(
            request: Request = .default,
            verify: Verify = .default,
            resend: Resend = .default
        ) {
            self.request = request
            self.verify = verify
            self.resend = resend
        }
    }
}

// MARK: Phone Restoration URLs

extension Passage.Configuration {

    var phonePasswordResetURL: URL {
        origin.appending(path: (routes.group + restoration.phone.routes.verify.path).string)
    }

}

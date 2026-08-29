public import Foundation
public import Vapor

// MARK: - Passwordless Configuration

public extension Passage.Configuration {

    struct Passwordless: Sendable {
        let emailMagicLink: MagicLink?

        public init(
            emailMagicLink: MagicLink? = .email()
        ) {
            self.emailMagicLink = emailMagicLink
        }
    }

}

// MARK: - Passwordless Magic Link Configuration

public extension Passage.Configuration.Passwordless {

    struct MagicLink: Sendable {
        let routes: Routes
        let useQueues: Bool
        let linkExpiration: TimeInterval
        let maxAttempts: Int
        let autoCreateUser: Bool
        let requireSameBrowser: Bool

        public static func email(
            routes: Routes = .email,
            useQueues: Bool = true,
            linkExpiration: TimeInterval = 15 * 60, // 15 minutes
            maxAttempts: Int = 5,
            autoCreateUser: Bool = true,
            requireSameBrowser: Bool = false
        ) -> MagicLink {
            return MagicLink(
                routes: routes,
                useQueues: useQueues,
                linkExpiration: linkExpiration,
                maxAttempts: maxAttempts,
                autoCreateUser: autoCreateUser,
                requireSameBrowser: requireSameBrowser,
            )
        }
    }

}

// MARK: Passwordless Magic Link Routes

public extension Passage.Configuration.Passwordless.MagicLink {

    struct Routes: Sendable {

        public static let email = Routes(
            request: .init(path: "magic-link", "email"),
            verify: .init(path: "magic-link", "email", "verify"),
            resend: .init(path: "magic-link", "email", "resend")
        )

        public struct Request: Sendable {
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct Verify: Sendable {
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct Resend: Sendable {
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        let request: Request
        let verify: Verify
        let resend: Resend

        public init(
            request: Request,
            verify: Verify,
            resend: Resend
        ) {
            self.request = request
            self.verify = verify
            self.resend = resend
        }
    }
}


// MARK: Magic Link URLs

extension Passage.Configuration {

    /// Base URL for email magic link verification
    var emailMagicLinkVerifyURL: URL? {
        guard let emailMagicLink = passwordless.emailMagicLink else { return nil }
        return origin.appending(path: (routes.group + emailMagicLink.routes.verify.path).string)
    }

    /// Constructs the email magic link URL with the given token as a query parameter
    func emailMagicLinkURL(token: String) -> URL? {
        return emailMagicLinkVerifyURL?.appending(queryItems: [
            URLQueryItem(name: "token", value: token)
        ])
    }

}

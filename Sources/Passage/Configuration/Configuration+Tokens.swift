public import Foundation

// MARK: - Tokens

extension Passage.Configuration {

    public struct Tokens: Sendable {
        let issuer: String?

        let idToken: IdToken
        let accessToken: AccessToken
        let refreshToken: RefreshToken

        public init(
            issuer: String? = nil,
            idToken: IdToken = .init(timeToLive: 1 * 3600),
            accessToken: AccessToken = .init(timeToLive: 15 * 60),
            refreshToken: RefreshToken = .init(timeToLive: 7 * 24 * 3600),
        ) {
            self.issuer = issuer
            self.idToken = idToken
            self.accessToken = accessToken
            self.refreshToken = refreshToken
        }
    }

}

// MARK: - IdToken Configurations

public extension Passage.Configuration.Tokens {

    struct IdToken: Sendable {
        let timeToLive: TimeInterval
        public init(timeToLive: TimeInterval) {
            self.timeToLive = timeToLive
        }
    }

}

// MARK: - AccessToken Configurations

public extension Passage.Configuration.Tokens {

    struct AccessToken: Sendable {
        let timeToLive: TimeInterval
        public init(timeToLive: TimeInterval) {
            self.timeToLive = timeToLive
        }
    }

}

// MARK: - RefreshToken Configurations

public extension Passage.Configuration.Tokens {

    struct RefreshToken: Sendable {
        let timeToLive: TimeInterval
        let concurrency: Concurrency

        public init(
            timeToLive: TimeInterval,
            concurrency: Concurrency = .unlimited
        ) {
            if case .limit(let n) = concurrency {
                precondition(n >= 1, "limit(n) must have n >= 1")
            }
            self.timeToLive = timeToLive
            self.concurrency = concurrency
        }

        public enum Concurrency: Sendable, Equatable {
            case unlimited
            case single
            case limit(Int)
        }
    }

}

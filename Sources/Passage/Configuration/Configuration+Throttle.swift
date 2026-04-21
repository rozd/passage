import Foundation

// MARK: - Throttle Configuration

public extension Passage.Configuration {

    struct Throttle: Sendable {
        let login: Login

        public init(
            login: Login = .init(),
        ) {
            self.login = login
        }
    }

}

public extension Passage.Configuration.Throttle {

    struct Login: Sendable {
        let perIdentifier: Passage.Throttle.Rule
        let perSource: Passage.Throttle.Rule
        let enabled: Bool

        public init(
            perIdentifier: Passage.Throttle.Rule = .init(maxFailures: 10, window: 15 * 60),
            perSource: Passage.Throttle.Rule = .init(maxFailures: 20, window: 15 * 60),
            enabled: Bool = true
        ) {
            self.perIdentifier = perIdentifier
            self.perSource = perSource
            self.enabled = enabled
        }
    }

}

public import Vapor

// MARK: - Federated Login Configuration

public extension Passage.Configuration {

    struct FederatedLogin: Sendable {
        public let routes: Routes
        public let providers: [Provider]
        public let redirectLocation: String
        public let accountLinking: AccountLinking

        public init(
            routes: Routes = .init(),
            providers: [Provider],
            accountLinking: AccountLinking = .init(resolution: .disabled),
            redirectLocation: String = "/"
        ) {
            self.routes = routes
            self.providers = providers
            self.accountLinking = accountLinking
            self.redirectLocation = redirectLocation
        }
    }

}

// MARK: - Federated Login Routes

public extension Passage.Configuration.FederatedLogin {

    struct Routes: Sendable {
        let group: [PathComponent]

        public init(group: PathComponent...) {
            self.group = group
        }

        public init() {
            self.group = ["connect"]
        }
    }
}

// MARK: - Federated Provider Configuration

public extension Passage.Configuration.FederatedLogin {

    struct Provider: Sendable {
        public let provider: FederatedProvider
        public let routes: Routes

        public init(
            provider: FederatedProvider,
            routes: Routes? = nil,
        ) {
            self.provider = provider
            self.routes = routes ?? .init(
                login: .init(path: provider.name.description.pathComponents),
                callback: .init(path: provider.name.description.pathComponents + ["callback"])
            )
        }
    }
}

// MARK: Federated Login Path Helpers

public extension Passage.Configuration.FederatedLogin {
    func loginPath(for provider: Provider) -> [PathComponent] {
        return routes.group + provider.routes.login.path
    }
    func callbackPath(for provider: Provider) -> [PathComponent] {
        return routes.group + provider.routes.callback.path
    }
    var linkAccountSelectPath: [PathComponent] {
        return routes.group + accountLinking.routes.select
    }
    var linkAccountVerifyPath: [PathComponent] {
        return routes.group + accountLinking.routes.verify
    }
}


// MARK: - Federated Provider Routes Configuration

public extension Passage.Configuration.FederatedLogin.Provider {

    struct Routes: Sendable {

        public struct Login: Sendable {
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
            public init(path: [PathComponent]) {
                self.path = path
            }
        }

        public struct Callback: Sendable {
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
            public init(path: [PathComponent]) {
                self.path = path
            }
        }

        let login: Login
        let callback: Callback

        public init(
            login: Login = .init(),
            callback: Callback = .init(path: "callback")
        ) {
            self.login = login
            self.callback = callback
        }
    }
}

// MARK: - Account Linking Configuration

public extension Passage.Configuration.FederatedLogin {

    struct AccountLinking: Sendable {
        public let resolution: LinkingResolution
        public let stateExpiration: TimeInterval
        public let routes: Routes

        public init(
            resolution: LinkingResolution,
            stateExpiration: TimeInterval = 600,
            routes: Routes = .init()
        ) {
            self.resolution = resolution
            self.stateExpiration = stateExpiration
            self.routes = routes
        }

        var enabled: Bool {
            switch resolution {
            case .disabled:
                return false
            case .automatic, .manual:
                return true
            }
        }
    }
}

// MARK: - Account Linking Routes Configuration

public extension Passage.Configuration.FederatedLogin.AccountLinking {
    struct Routes: Sendable {
        public let select: [PathComponent]
        public let verify: [PathComponent]

        public init(
            select: [PathComponent] = ["link", "select"],
            verify: [PathComponent] = ["link", "verify"]
        ) {
            self.select = select
            self.verify = verify
        }
    }
}

public import Vapor

// MARK: - Main Routes Configuration

public extension Passage.Configuration {

    struct Routes: Sendable {
        public struct Register: Sendable {
            public static let `default` = Register(path: "register")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct Login: Sendable {
            public static let `default` = Login(path: "login")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct Logout: Sendable {
            public static let `default` = Logout(path: "logout")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct RefreshToken: Sendable {
            public static let `default` = RefreshToken(path: "refresh-token")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct ExchangeCode: Sendable {
            public static let `default` = ExchangeCode(path: "token", "exchange")
            let path: [PathComponent]
            public init(path: PathComponent...) {
                self.path = path
            }
        }

        public struct CurrentUser: Sendable {
            public static let `default` = CurrentUser(path: "me")
            let path: [PathComponent]
            let shouldBypassGroup: Bool
            public init(path: PathComponent..., shouldBypassGroup: Bool = true) {
                self.path = path
                self.shouldBypassGroup = shouldBypassGroup
            }
        }

        let group: [PathComponent]
        let register: Register
        let login: Login
        let logout: Logout
        let refreshToken: RefreshToken
        let exchangeCode: ExchangeCode
        let currentUser: CurrentUser

        private init(
            group: [PathComponent],
            register: Register,
            login: Login,
            logout: Logout,
            refreshToken: RefreshToken,
            exchangeCode: ExchangeCode,
            currentUser: CurrentUser,
        ) {
            self.group = group
            self.register = register
            self.login = login
            self.logout = logout
            self.refreshToken = refreshToken
            self.exchangeCode = exchangeCode
            self.currentUser = currentUser
        }

        public init(
            group: PathComponent...,
            register: Register         = .default,
            login: Login               = .default,
            logout: Logout             = .default,
            refreshToken: RefreshToken = .default,
            exchangeCode: ExchangeCode = .default,
            currentUser: CurrentUser   = .default,
        ) {
            self.init(
                group: group,
                register: register,
                login: login,
                logout: logout,
                refreshToken: refreshToken,
                exchangeCode: exchangeCode,
                currentUser: currentUser
            )
        }

        public init(
            register: Register         = .default,
            login: Login               = .default,
            logout: Logout             = .default,
            refreshToken: RefreshToken = .default,
            exchangeCode: ExchangeCode = .default,
            currentUser: CurrentUser   = .default,
        ) {
            self.init(
                group: ["auth"],
                register: register,
                login: login,
                logout: logout,
                refreshToken: refreshToken,
                exchangeCode: exchangeCode,
                currentUser: currentUser
            )
        }
    }
}

import Testing
import Vapor
@testable import Passage

@Suite(.tags(.unit))
struct `Exchange Code Configuration Tests` {

    // MARK: - Default Configuration Tests

    @Test
    func `ExchangeCode default path is token/exchange`() {
        let exchangeCode = Passage.Configuration.Routes.ExchangeCode.default

        #expect(exchangeCode.path.count == 2)
        #expect(exchangeCode.path[0] == PathComponent.constant("token"))
        #expect(exchangeCode.path[1] == PathComponent.constant("exchange"))
    }

    @Test
    func `ExchangeCode can be initialized with custom path`() {
        let exchangeCode = Passage.Configuration.Routes.ExchangeCode(path: "oauth", "exchange")

        #expect(exchangeCode.path.count == 2)
        #expect(exchangeCode.path[0] == PathComponent.constant("oauth"))
        #expect(exchangeCode.path[1] == PathComponent.constant("exchange"))
    }

    @Test
    func `ExchangeCode can be initialized with single path component`() {
        let exchangeCode = Passage.Configuration.Routes.ExchangeCode(path: "exchange")

        #expect(exchangeCode.path.count == 1)
        #expect(exchangeCode.path[0] == PathComponent.constant("exchange"))
    }

    @Test
    func `ExchangeCode can be initialized with deep path`() {
        let exchangeCode = Passage.Configuration.Routes.ExchangeCode(path: "api", "v1", "auth", "exchange")

        #expect(exchangeCode.path.count == 4)
        #expect(exchangeCode.path[0] == PathComponent.constant("api"))
        #expect(exchangeCode.path[1] == PathComponent.constant("v1"))
        #expect(exchangeCode.path[2] == PathComponent.constant("auth"))
        #expect(exchangeCode.path[3] == PathComponent.constant("exchange"))
    }

    // MARK: - Routes Configuration Integration Tests

    @Test
    func `Routes includes exchangeCode property`() {
        let routes = Passage.Configuration.Routes()

        #expect(routes.exchangeCode.path.count == 2)
    }

    @Test
    func `Routes uses default exchangeCode when not specified`() {
        let routes = Passage.Configuration.Routes()

        #expect(routes.exchangeCode.path == Passage.Configuration.Routes.ExchangeCode.default.path)
    }

    @Test
    func `Routes accepts custom exchangeCode`() {
        let customExchangeCode = Passage.Configuration.Routes.ExchangeCode(path: "custom", "path")
        let routes = Passage.Configuration.Routes(exchangeCode: customExchangeCode)

        #expect(routes.exchangeCode.path == customExchangeCode.path)
    }

    @Test
    func `Routes preserves exchangeCode with other custom routes`() {
        let customExchangeCode = Passage.Configuration.Routes.ExchangeCode(path: "code", "swap")
        let customLogin = Passage.Configuration.Routes.Login(path: "signin")

        let routes = Passage.Configuration.Routes(
            login: customLogin,
            exchangeCode: customExchangeCode
        )

        #expect(routes.exchangeCode.path == customExchangeCode.path)
        #expect(routes.login.path == customLogin.path)
    }

    @Test
    func `Routes with group and custom exchangeCode`() {
        let customExchangeCode = Passage.Configuration.Routes.ExchangeCode(path: "exchange")

        let routes = Passage.Configuration.Routes(
            group: "api", "v2",
            exchangeCode: customExchangeCode
        )

        #expect(routes.group.count == 2)
        #expect(routes.group[0] == PathComponent.constant("api"))
        #expect(routes.group[1] == PathComponent.constant("v2"))
        #expect(routes.exchangeCode.path == customExchangeCode.path)
    }

    // MARK: - Sendable Conformance

    @Test
    func `ExchangeCode conforms to Sendable`() {
        let exchangeCode: any Sendable = Passage.Configuration.Routes.ExchangeCode.default
        #expect(exchangeCode is Passage.Configuration.Routes.ExchangeCode)
    }
}

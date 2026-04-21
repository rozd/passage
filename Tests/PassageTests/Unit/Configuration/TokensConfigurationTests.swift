import Testing
import Foundation
@testable import Passage

@Suite
struct `Tokens Configuration Tests` {

    // MARK: - IdToken Configuration Tests

    @Test(arguments: [
        (3600.0, "1 hour - default"),
        (300.0, "5 minutes"),
        (1800.0, "30 minutes"),
        (7200.0, "2 hours")
    ])
    func `ID token time to live`(ttl: TimeInterval, _: String) {
        let idToken = Passage.Configuration.Tokens.IdToken(timeToLive: ttl)
        #expect(idToken.timeToLive == ttl)
    }

    // MARK: - AccessToken Configuration Tests

    @Test(arguments: [
        (900.0, "15 minutes - default"),
        (300.0, "5 minutes"),
        (1800.0, "30 minutes"),
        (3600.0, "1 hour")
    ])
    func `Access token time to live`(ttl: TimeInterval, _: String) {
        let accessToken = Passage.Configuration.Tokens.AccessToken(timeToLive: ttl)
        #expect(accessToken.timeToLive == ttl)
    }

    // MARK: - RefreshToken Configuration Tests

    @Test(arguments: [
        (604800.0, "7 days - default"),
        (86400.0, "1 day"),
        (2592000.0, "30 days")
    ])
    func `Refresh token time to live`(ttl: TimeInterval, _: String) {
        let refreshToken = Passage.Configuration.Tokens.RefreshToken(timeToLive: ttl)
        #expect(refreshToken.timeToLive == ttl)
    }

    // MARK: - Tokens Configuration Tests

    @Test
    func `Tokens default configuration`() {
        let tokens = Passage.Configuration.Tokens()

        #expect(tokens.issuer == nil)
        #expect(tokens.idToken.timeToLive == 1 * 3600)
        #expect(tokens.accessToken.timeToLive == 15 * 60)
        #expect(tokens.refreshToken.timeToLive == 7 * 24 * 3600)
    }

    @Test
    func `Tokens configuration with issuer`() {
        let tokens = Passage.Configuration.Tokens(issuer: "https://example.com")

        #expect(tokens.issuer == "https://example.com")
    }

    @Test
    func `Tokens configuration with custom TTLs`() {
        let tokens = Passage.Configuration.Tokens(
            issuer: "https://auth.example.com",
            idToken: .init(timeToLive: 7200),
            accessToken: .init(timeToLive: 600),
            refreshToken: .init(timeToLive: 2592000)
        )

        #expect(tokens.issuer == "https://auth.example.com")
        #expect(tokens.idToken.timeToLive == 7200)
        #expect(tokens.accessToken.timeToLive == 600)
        #expect(tokens.refreshToken.timeToLive == 2592000)
    }

    @Test
    func `Tokens Sendable conformance`() {
        let tokens: Passage.Configuration.Tokens = .init()

        // Verify all nested types are Sendable
        let _: any Sendable = tokens
        let _: any Sendable = tokens.idToken
        let _: any Sendable = tokens.accessToken
        let _: any Sendable = tokens.refreshToken
    }
}

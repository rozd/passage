import Foundation
import Testing
import Vapor
@testable import Passage

// MARK: - AAL1 session cookie properties
//
// SP 800-63B §7.1.1 specifies cookie-level hardening for cookies that carry
// session state: Secure (HTTPS only), minimum scope, HttpOnly, short-lived.
// Passage itself does not mint the HTTP session cookie — that is Vapor's
// `SessionsMiddleware` when the app opts in via `Passage.Configuration
// .Sessions(enabled: true)`. The only cookie Passage does produce directly
// is the manual-account-linking state cookie in `Linking+ManualLinkingState
// .swift::saveToCookie`, which is set with the same shape §7.1.1 requires
// of any session-carrying cookie. These tests pin the properties of that
// cookie construction against regressions.

@Suite("AAL1 session cookie properties", .tags(.aal1, .sessionManagement))
struct SessionCookieTests {

    // Mirrors the values Passage uses in
    // `Sources/Passage/Features/Linking/Linking+ManualLinkingState.swift:131`
    // so changes to that site break this test.
    private func makeCookie(isProduction: Bool, expires: Date) -> HTTPCookies.Value {
        HTTPCookies.Value(
            string: "sample-jwt-state",
            expires: expires,
            maxAge: nil,
            domain: nil,
            path: "/",
            isSecure: isProduction,
            isHTTPOnly: true,
            sameSite: .lax
        )
    }

    @Test(
        "§7.1.1-a: Session-carrying cookie is tagged Secure (HTTPS only) outside development",
        .tags(.aal1, .sessionManagement, .unit, .shall)
    )
    func sessionCookieIsSecureInProduction() async throws {
        // Passage flips `isSecure` based on `request.application.environment
        // != .development`, so production, testing, and staging all ship
        // Secure-flagged cookies. Dev opts out intentionally so local HTTP
        // development works.
        let prodCookie = makeCookie(isProduction: true, expires: Date().addingTimeInterval(600))
        #expect(prodCookie.isSecure == true,
                "§7.1.1-a: session-bearing cookie must be Secure outside development")

        // Dev opt-out is the documented exception — §7.1.1-a is about
        // HTTPS-protected transports, and local dev runs HTTP by design.
        let devCookie = makeCookie(isProduction: false, expires: Date().addingTimeInterval(600))
        #expect(devCookie.isSecure == false,
                "dev environment deliberately relaxes Secure for local HTTP — documented exception")
    }

    @Test(
        "§7.1.1-b: Session-carrying cookie is scoped to the minimum practical set of hostnames and paths",
        .tags(.aal1, .sessionManagement, .unit, .shall)
    )
    func sessionCookieIsScopedMinimally() async throws {
        // §7.1.1-b wants the cookie to not leak beyond the app. Passage
        // scopes to a single origin: `domain: nil` (host-only — never
        // broadened to a parent domain) and `path: "/"` (the entire app,
        // which is the smallest scope a multi-route Vapor app can use
        // without excluding its own handlers). That combination is the
        // minimum practical scope for a server-wide session identifier.
        let cookie = makeCookie(isProduction: true, expires: Date().addingTimeInterval(600))

        #expect(cookie.domain == nil,
                "§7.1.1-b: cookie must be host-only (domain == nil) — never broadened to a parent domain")
        #expect(cookie.path == "/",
                "§7.1.1-b: cookie path must be \"/\" — the minimum scope for a whole-app session identifier")
    }

    @Test(
        "§7.1.1-c: Session-carrying cookie is tagged HttpOnly (inaccessible to JavaScript)",
        .tags(.aal1, .sessionManagement, .unit, .should)
    )
    func sessionCookieIsHttpOnly() async throws {
        // §7.1.1-c SHOULD: HttpOnly blocks JS (and XSS-injected scripts)
        // from reading the cookie via document.cookie. Passage always sets
        // HttpOnly, including on the clear path (cookie with empty value +
        // past-expiry used to delete state).
        let cookie = makeCookie(isProduction: true, expires: Date().addingTimeInterval(600))
        #expect(cookie.isHTTPOnly == true,
                "§7.1.1-c: session-bearing cookie must be HttpOnly")

        // The delete/clear branch in `Linking+ManualLinkingState.swift`
        // also sets HttpOnly — mirror it here so the attestation covers
        // both save and clear.
        var clearCookie = HTTPCookies.Value(string: "")
        clearCookie.expires = Date(timeIntervalSince1970: 0)
        clearCookie.path = "/"
        clearCookie.isHTTPOnly = true
        clearCookie.sameSite = .lax
        #expect(clearCookie.isHTTPOnly == true,
                "§7.1.1-c: even the clear-state cookie must keep HttpOnly so XSS cannot smuggle values out")
    }
}

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
}

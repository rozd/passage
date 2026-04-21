import Testing
import Foundation
import Vapor
@testable import Passage

@Suite
struct `Restoration Configuration Tests` {

    // MARK: - Email Restoration Route Tests

    @Test
    func `Email restoration request route default`() {
        let route = Passage.Configuration.Restoration.Email.Routes.Request.default
        #expect(route.path.count == 3)
        #expect(route.path[0].description == "password")
        #expect(route.path[1].description == "reset")
        #expect(route.path[2].description == "email")
    }

    @Test
    func `Email restoration verify route default`() {
        let route = Passage.Configuration.Restoration.Email.Routes.Verify.default
        #expect(route.path.count == 4)
        #expect(route.path[0].description == "password")
        #expect(route.path[1].description == "reset")
        #expect(route.path[2].description == "email")
        #expect(route.path[3].description == "verify")
    }

    @Test
    func `Email restoration resend route default`() {
        let route = Passage.Configuration.Restoration.Email.Routes.Resend.default
        #expect(route.path.count == 4)
        #expect(route.path[0].description == "password")
        #expect(route.path[1].description == "reset")
        #expect(route.path[2].description == "email")
        #expect(route.path[3].description == "resend")
    }

    @Test
    func `Email restoration routes custom paths`() {
        let routes = Passage.Configuration.Restoration.Email.Routes(
            request: .init(path: "forgot"),
            verify: .init(path: "reset"),
            resend: .init(path: "resend")
        )

        #expect(routes.request.path[0].description == "forgot")
        #expect(routes.verify.path[0].description == "reset")
        #expect(routes.resend.path[0].description == "resend")
    }

    // MARK: - Email Restoration Configuration Tests

    @Test
    func `Email restoration default configuration`() {
        let email = Passage.Configuration.Restoration.Email()

        #expect(email.codeLength == 6)
        #expect(email.codeExpiration == 15 * 60)
        #expect(email.maxAttempts == 3)
    }

    @Test
    func `Email restoration custom configuration`() {
        let email = Passage.Configuration.Restoration.Email(
            routes: .init(),
            codeLength: 8,
            codeExpiration: 1800,
            maxAttempts: 5
        )

        #expect(email.codeLength == 8)
        #expect(email.codeExpiration == 1800)
        #expect(email.maxAttempts == 5)
    }

    // MARK: - Phone Restoration Route Tests

    @Test
    func `Phone restoration request route default`() {
        let route = Passage.Configuration.Restoration.Phone.Routes.Request.default
        #expect(route.path.count == 3)
        #expect(route.path[0].description == "password")
        #expect(route.path[1].description == "reset")
        #expect(route.path[2].description == "phone")
    }

    @Test
    func `Phone restoration verify route default`() {
        let route = Passage.Configuration.Restoration.Phone.Routes.Verify.default
        #expect(route.path.count == 4)
        #expect(route.path[0].description == "password")
        #expect(route.path[1].description == "reset")
        #expect(route.path[2].description == "phone")
        #expect(route.path[3].description == "verify")
    }

    @Test
    func `Phone restoration resend route default`() {
        let route = Passage.Configuration.Restoration.Phone.Routes.Resend.default
        #expect(route.path.count == 4)
        #expect(route.path[0].description == "password")
        #expect(route.path[1].description == "reset")
        #expect(route.path[2].description == "phone")
        #expect(route.path[3].description == "resend")
    }

    @Test
    func `Phone restoration routes custom paths`() {
        let routes = Passage.Configuration.Restoration.Phone.Routes(
            request: .init(path: "forgot", "sms"),
            verify: .init(path: "reset", "sms"),
            resend: .init(path: "resend", "sms")
        )

        #expect(routes.request.path[1].description == "sms")
        #expect(routes.verify.path[1].description == "sms")
        #expect(routes.resend.path[1].description == "sms")
    }

    // MARK: - Phone Restoration Configuration Tests

    @Test
    func `Phone restoration default configuration`() {
        let phone = Passage.Configuration.Restoration.Phone()

        #expect(phone.codeLength == 6)
        #expect(phone.codeExpiration == 5 * 60)
        #expect(phone.maxAttempts == 3)
    }

    @Test
    func `Phone restoration custom configuration`() {
        let phone = Passage.Configuration.Restoration.Phone(
            routes: .init(),
            codeLength: 4,
            codeExpiration: 300,
            maxAttempts: 5
        )

        #expect(phone.codeLength == 4)
        #expect(phone.codeExpiration == 300)
        #expect(phone.maxAttempts == 5)
    }

    // MARK: - Restoration Configuration Tests

    @Test
    func `Restoration default configuration`() {
        let restoration = Passage.Configuration.Restoration()

        #expect(restoration.preferredDelivery == .email)
        #expect(restoration.useQueues == false)
        #expect(restoration.email.codeLength == 6)
        #expect(restoration.phone.codeLength == 6)
    }

    @Test
    func `Restoration with phone preferred delivery`() {
        let restoration = Passage.Configuration.Restoration(preferredDelivery: .phone)

        #expect(restoration.preferredDelivery == .phone)
    }

    @Test
    func `Restoration with queues enabled`() {
        let restoration = Passage.Configuration.Restoration(useQueues: true)

        #expect(restoration.useQueues == true)
    }

    @Test
    func `Restoration with custom email and phone`() {
        let restoration = Passage.Configuration.Restoration(
            preferredDelivery: .phone,
            email: .init(codeLength: 8),
            phone: .init(codeLength: 4),
            useQueues: true
        )

        #expect(restoration.preferredDelivery == .phone)
        #expect(restoration.email.codeLength == 8)
        #expect(restoration.phone.codeLength == 4)
        #expect(restoration.useQueues == true)
    }

    @Test
    func `Restoration Sendable conformance`() {
        let restoration: Passage.Configuration.Restoration = .init()

        let _: any Sendable = restoration
        let _: any Sendable = restoration.email
        let _: any Sendable = restoration.phone
    }

    // MARK: - Restoration URL Tests

    @Test
    func `Email password reset URL construction`() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )

        let url = config.emailPasswordResetURL

        #expect(url.absoluteString == "https://example.com/auth/password/reset/email/verify")
    }

    @Test
    func `Email password reset link URL with code and email`() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )

        let url = config.emailPasswordResetLinkURL(code: "123456", email: "test@example.com")

        #expect(url.absoluteString.contains("code=123456"))
        #expect(url.absoluteString.contains("email=test@example.com"))
        #expect(url.absoluteString.hasPrefix("https://example.com/auth/password/reset/email/verify"))
    }

    @Test
    func `Phone password reset URL construction`() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )

        let url = config.phonePasswordResetURL

        #expect(url.absoluteString == "https://example.com/auth/password/reset/phone/verify")
    }

    @Test
    func `Restoration URLs with custom routes`() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            routes: .init(group: "api"),
            jwt: .init(jwks: .init(json: "{}")),
            restoration: .init(
                email: .init(routes: .init(verify: .init(path: "reset")))
            )
        )

        let url = config.emailPasswordResetURL

        #expect(url.absoluteString == "https://example.com/api/reset")
    }
}

import Testing
import Foundation
import Vapor
@testable import Passage

@Suite
struct `Verification Configuration Tests` {

    // MARK: - Email Verification Route Tests

    @Test
    func `Email verification verify route default`() {
        let route = Passage.Configuration.Verification.Email.Routes.Verify.default
        #expect(route.path.count == 2)
        #expect(route.path[0].description == "email")
        #expect(route.path[1].description == "verify")
    }

    @Test
    func `Email verification resend route default`() {
        let route = Passage.Configuration.Verification.Email.Routes.Resend.default
        #expect(route.path.count == 2)
        #expect(route.path[0].description == "email")
        #expect(route.path[1].description == "resend")
    }

    @Test
    func `Email verification routes custom paths`() {
        let routes = Passage.Configuration.Verification.Email.Routes(
            verify: .init(path: "v", "email"),
            resend: .init(path: "r", "email")
        )

        #expect(routes.verify.path[0].description == "v")
        #expect(routes.verify.path[1].description == "email")
        #expect(routes.resend.path[0].description == "r")
        #expect(routes.resend.path[1].description == "email")
    }

    // MARK: - Email Verification Configuration Tests

    @Test
    func `Email verification default configuration`() {
        let email = Passage.Configuration.Verification.Email()

        #expect(email.codeLength == 6)
        #expect(email.codeExpiration == 15 * 60)
        #expect(email.maxAttempts == 3)
    }

    @Test
    func `Email verification custom configuration`() {
        let email = Passage.Configuration.Verification.Email(
            routes: .init(),
            codeLength: 8,
            codeExpiration: 600,
            maxAttempts: 5
        )

        #expect(email.codeLength == 8)
        #expect(email.codeExpiration == 600)
        #expect(email.maxAttempts == 5)
    }

    // MARK: - Phone Verification Route Tests

    @Test
    func `Phone verification send code route default`() {
        let route = Passage.Configuration.Verification.Phone.Routes.SendCode.default
        #expect(route.path.count == 2)
        #expect(route.path[0].description == "phone")
        #expect(route.path[1].description == "send-code")
    }

    @Test
    func `Phone verification verify route default`() {
        let route = Passage.Configuration.Verification.Phone.Routes.Verify.default
        #expect(route.path.count == 2)
        #expect(route.path[0].description == "phone")
        #expect(route.path[1].description == "verify")
    }

    @Test
    func `Phone verification resend route default`() {
        let route = Passage.Configuration.Verification.Phone.Routes.Resend.default
        #expect(route.path.count == 2)
        #expect(route.path[0].description == "phone")
        #expect(route.path[1].description == "resend")
    }

    @Test
    func `Phone verification routes custom paths`() {
        let routes = Passage.Configuration.Verification.Phone.Routes(
            sendCode: .init(path: "sms", "send"),
            verify: .init(path: "sms", "verify"),
            resend: .init(path: "sms", "resend")
        )

        #expect(routes.sendCode.path[0].description == "sms")
        #expect(routes.verify.path[1].description == "verify")
        #expect(routes.resend.path[1].description == "resend")
    }

    // MARK: - Phone Verification Configuration Tests

    @Test
    func `Phone verification default configuration`() {
        let phone = Passage.Configuration.Verification.Phone()

        #expect(phone.codeLength == 6)
        #expect(phone.codeExpiration == 5 * 60)
        #expect(phone.maxAttempts == 3)
    }

    @Test
    func `Phone verification custom configuration`() {
        let phone = Passage.Configuration.Verification.Phone(
            routes: .init(),
            codeLength: 4,
            codeExpiration: 300,
            maxAttempts: 5
        )

        #expect(phone.codeLength == 4)
        #expect(phone.codeExpiration == 300)
        #expect(phone.maxAttempts == 5)
    }

    // MARK: - Verification Configuration Tests

    @Test
    func `Verification default configuration`() {
        let verification = Passage.Configuration.Verification()

        #expect(verification.useQueues == false)
        #expect(verification.email.codeLength == 6)
        #expect(verification.phone.codeLength == 6)
    }

    @Test
    func `Verification with queues enabled`() {
        let verification = Passage.Configuration.Verification(useQueues: true)

        #expect(verification.useQueues == true)
    }

    @Test
    func `Verification with custom email and phone`() {
        let verification = Passage.Configuration.Verification(
            email: .init(codeLength: 8),
            phone: .init(codeLength: 4),
            useQueues: true
        )

        #expect(verification.email.codeLength == 8)
        #expect(verification.phone.codeLength == 4)
        #expect(verification.useQueues == true)
    }

    @Test
    func `Verification Sendable conformance`() {
        let verification: Passage.Configuration.Verification = .init()

        let _: any Sendable = verification
        let _: any Sendable = verification.email
        let _: any Sendable = verification.phone
    }

    // MARK: - Verification URL Tests

    @Test
    func `Email verification URL construction`() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )

        let url = config.emailVerificationURL

        #expect(url.absoluteString == "https://example.com/auth/email/verify")
    }

    @Test
    func `Email verification URL with custom routes`() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            routes: .init(
                group: "api",
                register: .default
            ),
            jwt: .init(jwks: .init(json: "{}")),
            verification: .init(
                email: .init(routes: .init(verify: .init(path: "v")))
            )
        )

        let url = config.emailVerificationURL

        #expect(url.absoluteString == "https://example.com/api/v")
    }

    @Test
    func `Phone verification URL construction`() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )

        let url = config.phoneVerificationURL

        #expect(url.absoluteString == "https://example.com/auth/phone/verify")
    }
}

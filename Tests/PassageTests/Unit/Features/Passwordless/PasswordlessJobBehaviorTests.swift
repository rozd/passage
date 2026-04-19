import Testing
import Foundation
import Vapor
import Queues
@testable import Passage
@testable import PassageOnlyForTest

@Suite("Passwordless Job Behavior Tests", .tags(.unit, .passwordless))
struct PasswordlessJobBehaviorTests {

    // MARK: - Helpers

    @Sendable private func createMockQueueContext(
        app: Application,
        logger: CapturingLogger
    ) -> QueueContext {
        QueueContext(
            queueName: .init(string: "test"),
            configuration: .init(),
            application: app,
            logger: Logger(label: "test", factory: { _ in logger }),
            on: app.eventLoopGroup.next()
        )
    }

    @Sendable private func configurePassage(_ app: Application, emailDelivery: (any Passage.EmailDelivery)?) async throws {
        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: emailDelivery,
            phoneDelivery: nil,
            federatedLogin: nil
        )
        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: #"{"keys":[]}"#)),
            passwordless: .init(
                emailMagicLink: .email(
                    useQueues: true,
                    linkExpiration: 600,
                    maxAttempts: 3,
                    autoCreateUser: true,
                    requireSameBrowser: false
                )
            )
        )
        try await app.passage.configure(services: services, configuration: configuration)
    }

    // MARK: - dequeue: no email delivery configured

    @Test("dequeue logs warning when email delivery is not configured")
    func dequeueLogsWarningWhenNoEmailDelivery() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        try await configurePassage(app, emailDelivery: nil)

        let payload = Passage.Passwordless.EmailMagicLinkPayload(
            email: "test@example.com",
            userId: nil,
            magicLinkURL: URL(string: "https://example.com/verify?token=abc")!
        )

        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        let job = Passage.Passwordless.SendEmailMagicLinkJob()
        try await job.dequeue(context, payload)

        #expect(capturingLogger.warnings.count == 1)
        #expect(capturingLogger.warnings.first?.contains("Email delivery not configured") == true)
        #expect(capturingLogger.warnings.first?.contains("magic link") == true)
    }

    // MARK: - dequeue: delivery with nil userId

    @Test("dequeue calls delivery with nil user when userId is nil")
    func dequeueCallsDeliveryWithNilUser() async throws {
        final class RecordingEmailDelivery: Passage.EmailDelivery, @unchecked Sendable {
            var capturedUser: (any User)?
            var capturedEmail: String?
            var called = false

            func sendEmailVerification(to email: String, user: any User, verificationURL: URL, verificationCode: String) async throws {}
            func sendEmailVerificationConfirmation(to email: String, user: any User) async throws {}
            func sendPasswordResetEmail(to email: String, user: any User, passwordResetURL: URL, passwordResetCode: String) async throws {}
            func sendWelcomeEmail(to email: String, user: any User) async throws {}

            func sendMagicLinkEmail(to email: String, user: (any User)?, magicLinkURL: URL) async throws {
                called = true
                capturedEmail = email
                capturedUser = user
            }
        }

        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        let delivery = RecordingEmailDelivery()
        try await configurePassage(app, emailDelivery: delivery)

        let payload = Passage.Passwordless.EmailMagicLinkPayload(
            email: "new@example.com",
            userId: nil,
            magicLinkURL: URL(string: "https://example.com/verify?token=abc")!
        )

        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        let job = Passage.Passwordless.SendEmailMagicLinkJob()
        try await job.dequeue(context, payload)

        #expect(delivery.called == true)
        #expect(delivery.capturedEmail == "new@example.com")
        #expect(delivery.capturedUser == nil)
    }

    // MARK: - dequeue: delivery throws

    @Test("dequeue propagates error when delivery throws")
    func dequeueThrowsWhenDeliveryFails() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }
        let testError = MockDeliveryError(message: "SMTP connection refused")
        try await configurePassage(app, emailDelivery: FailingEmailDelivery(error: testError))

        let payload = Passage.Passwordless.EmailMagicLinkPayload(
            email: "fail@example.com",
            userId: nil,
            magicLinkURL: URL(string: "https://example.com/verify?token=abc")!
        )

        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        let job = Passage.Passwordless.SendEmailMagicLinkJob()
        await #expect(throws: MockDeliveryError.self) {
            try await job.dequeue(context, payload)
        }
    }

    // MARK: - error handler

    @Test("error handler logs error with email address")
    func errorHandlerLogsError() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        let payload = Passage.Passwordless.EmailMagicLinkPayload(
            email: "recipient@example.com",
            userId: "user-123",
            magicLinkURL: URL(string: "https://example.com/verify?token=abc")!
        )

        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        let job = Passage.Passwordless.SendEmailMagicLinkJob()
        let deliveryError = MockDeliveryError(message: "Timeout")
        try await job.error(context, deliveryError, payload)

        #expect(capturingLogger.errors.count == 1)
        #expect(capturingLogger.errors.first?.contains("recipient@example.com") == true)
        #expect(capturingLogger.errors.first?.contains("magic link") == true)
    }

    // MARK: - EmailMagicLinkPayload Codable

    @Test("EmailMagicLinkPayload encodes and decodes via Codable")
    func payloadCodableRoundtrip() throws {
        let original = Passage.Passwordless.EmailMagicLinkPayload(
            email: "round@example.com",
            userId: "abc-123",
            magicLinkURL: URL(string: "https://example.com/magic?token=xyz")!
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Passage.Passwordless.EmailMagicLinkPayload.self, from: data)

        #expect(decoded.email == original.email)
        #expect(decoded.userId == original.userId)
        #expect(decoded.magicLinkURL == original.magicLinkURL)
    }

    @Test("EmailMagicLinkPayload encodes and decodes with nil userId")
    func payloadCodableWithNilUserId() throws {
        let original = Passage.Passwordless.EmailMagicLinkPayload(
            email: "anon@example.com",
            userId: nil,
            magicLinkURL: URL(string: "https://example.com/magic?token=xyz")!
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Passage.Passwordless.EmailMagicLinkPayload.self, from: data)

        #expect(decoded.email == original.email)
        #expect(decoded.userId == nil)
    }
}

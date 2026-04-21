import Testing
import Vapor
import Queues
@testable import Passage
@testable import PassageOnlyForTest

@Suite(.tags(.unit))
struct `Restoration Jobs Tests` {

    /// Creates a mock QueueContext for testing
    @Sendable private func createMockQueueContext(
        app: Application,
        logger: CapturingLogger
    ) -> QueueContext {
        return QueueContext(
            queueName: .init(string: "test"),
            configuration: .init(),
            application: app,
            logger: Logger(label: "test", factory: { _ in logger }),
            on: app.eventLoopGroup.next()
        )
    }

    // MARK: - SendEmailPasswordResetCodeJob Tests

    @Test
    func `SendEmailPasswordResetCodeJob skips when email delivery is not configured`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        // Configure Passage without email delivery
        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: nil, // No email delivery configured
            phoneDelivery: nil,
            federatedLogin: nil
        )

        let emptyJwks = """
        {"keys":[]}
        """

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: emptyJwks))
        )

        try await app.passage.configure(services: services, configuration: configuration)

        // Create a test user
        let passwordHash = try await app.password.async.hash("password123")
        let identifier = Identifier.email("test@example.com")
        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)

        // Create job payload
        let payload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: user.id!.description,
            resetURL: URL(string: "http://localhost:8080/reset")!,
            resetCode: "123456"
        )

        // Create capturing logger and queue context
        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        // Execute the job
        let job = Passage.Restoration.SendEmailPasswordResetCodeJob()
        try await job.dequeue(context, payload)

        // Verify warning was logged
        #expect(capturingLogger.warnings.count == 1)
        #expect(capturingLogger.warnings.first?.contains("Email delivery not configured") == true)
        #expect(capturingLogger.warnings.first?.contains("password reset job") == true)
    }

    @Test
    func `SendEmailPasswordResetCodeJob skips when user is not found`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        // Configure Passage with email delivery
        let store = Passage.OnlyForTest.InMemoryStore()
        let emailDelivery = Passage.OnlyForTest.MockEmailDelivery()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: emailDelivery,
            phoneDelivery: nil,
            federatedLogin: nil
        )

        let emptyJwks = """
        {"keys":[]}
        """

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: emptyJwks))
        )

        try await app.passage.configure(services: services, configuration: configuration)

        // Create job payload with non-existent user ID
        let payload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: "non-existent-user-id",
            resetURL: URL(string: "http://localhost:8080/reset")!,
            resetCode: "123456"
        )

        // Create capturing logger and queue context
        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        // Execute the job
        let job = Passage.Restoration.SendEmailPasswordResetCodeJob()
        try await job.dequeue(context, payload)

        // Verify warning was logged
        #expect(capturingLogger.warnings.count == 1)
        #expect(capturingLogger.warnings.first?.contains("User not found") == true)
        #expect(capturingLogger.warnings.first?.contains("password reset job") == true)
        #expect(capturingLogger.warnings.first?.contains("non-existent-user-id") == true)
    }

    @Test
    func `SendEmailPasswordResetCodeJob error handler logs delivery errors`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        // Create job payload
        let payload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: "user123",
            resetURL: URL(string: "http://localhost:8080/reset")!,
            resetCode: "123456"
        )

        // Create capturing logger and queue context
        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        // Create the job and trigger error handler
        let job = Passage.Restoration.SendEmailPasswordResetCodeJob()
        let testError = MockDeliveryError(message: "SMTP connection failed")
        try await job.error(context, testError, payload)

        // Verify error was logged
        #expect(capturingLogger.errors.count == 1)
        #expect(capturingLogger.errors.first?.contains("Failed to send password reset email") == true)
        #expect(capturingLogger.errors.first?.contains("test@example.com") == true)
    }

    @Test
    func `SendEmailPasswordResetCodeJob throws error from email delivery`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        // Configure Passage with failing email delivery
        let store = Passage.OnlyForTest.InMemoryStore()
        let testError = MockDeliveryError(message: "Network timeout")
        let emailDelivery = FailingEmailDelivery(error: testError)
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: emailDelivery,
            phoneDelivery: nil,
            federatedLogin: nil
        )

        let emptyJwks = """
        {"keys":[]}
        """

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: emptyJwks))
        )

        try await app.passage.configure(services: services, configuration: configuration)

        // Create a test user
        let passwordHash = try await app.password.async.hash("password123")
        let identifier = Identifier.email("test@example.com")
        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)

        // Create job payload
        let payload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: user.id!.description,
            resetURL: URL(string: "http://localhost:8080/reset")!,
            resetCode: "123456"
        )

        // Create queue context
        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        // Execute the job and expect it to throw
        let job = Passage.Restoration.SendEmailPasswordResetCodeJob()
        await #expect(throws: MockDeliveryError.self) {
            try await job.dequeue(context, payload)
        }
    }

    // MARK: - SendPhonePasswordResetCodeJob Tests

    @Test
    func `SendPhonePasswordResetCodeJob skips when phone delivery is not configured`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        // Configure Passage without phone delivery
        let store = Passage.OnlyForTest.InMemoryStore()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: nil,
            phoneDelivery: nil, // No phone delivery configured
            federatedLogin: nil
        )

        let emptyJwks = """
        {"keys":[]}
        """

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: emptyJwks))
        )

        try await app.passage.configure(services: services, configuration: configuration)

        // Create a test user
        let passwordHash = try await app.password.async.hash("password123")
        let identifier = Identifier.phone("+1234567890")
        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)

        // Create job payload
        let payload = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: "123456",
            userId: user.id!.description
        )

        // Create capturing logger and queue context
        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        // Execute the job
        let job = Passage.Restoration.SendPhonePasswordResetCodeJob()
        try await job.dequeue(context, payload)

        // Verify warning was logged
        #expect(capturingLogger.warnings.count == 1)
        #expect(capturingLogger.warnings.first?.contains("Phone delivery not configured") == true)
        #expect(capturingLogger.warnings.first?.contains("password reset job") == true)
    }

    @Test
    func `SendPhonePasswordResetCodeJob skips when user is not found`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        // Configure Passage with phone delivery
        let store = Passage.OnlyForTest.InMemoryStore()
        let phoneDelivery = Passage.OnlyForTest.MockPhoneDelivery()
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: nil,
            phoneDelivery: phoneDelivery,
            federatedLogin: nil
        )

        let emptyJwks = """
        {"keys":[]}
        """

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: emptyJwks))
        )

        try await app.passage.configure(services: services, configuration: configuration)

        // Create job payload with non-existent user ID
        let payload = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: "123456",
            userId: "non-existent-user-id"
        )

        // Create capturing logger and queue context
        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        // Execute the job
        let job = Passage.Restoration.SendPhonePasswordResetCodeJob()
        try await job.dequeue(context, payload)

        // Verify warning was logged
        #expect(capturingLogger.warnings.count == 1)
        #expect(capturingLogger.warnings.first?.contains("User not found") == true)
        #expect(capturingLogger.warnings.first?.contains("phone password reset job") == true)
        #expect(capturingLogger.warnings.first?.contains("non-existent-user-id") == true)
    }

    @Test
    func `SendPhonePasswordResetCodeJob error handler logs delivery errors`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        // Create job payload
        let payload = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: "123456",
            userId: "user123"
        )

        // Create capturing logger and queue context
        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        // Create the job and trigger error handler
        let job = Passage.Restoration.SendPhonePasswordResetCodeJob()
        let testError = MockDeliveryError(message: "SMS service unavailable")
        try await job.error(context, testError, payload)

        // Verify error was logged
        #expect(capturingLogger.errors.count == 1)
        #expect(capturingLogger.errors.first?.contains("Failed to send password reset SMS") == true)
        #expect(capturingLogger.errors.first?.contains("+1234567890") == true)
    }

    @Test
    func `SendPhonePasswordResetCodeJob throws error from phone delivery`() async throws {
        let app = try await Application.make(.testing)
        defer { Task { try await app.asyncShutdown() } }

        // Configure Passage with failing phone delivery
        let store = Passage.OnlyForTest.InMemoryStore()
        let testError = MockDeliveryError(message: "SMS gateway error")
        let phoneDelivery = FailingPhoneDelivery(error: testError)
        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: nil,
            phoneDelivery: phoneDelivery,
            federatedLogin: nil
        )

        let emptyJwks = """
        {"keys":[]}
        """

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: emptyJwks))
        )

        try await app.passage.configure(services: services, configuration: configuration)

        // Create a test user
        let passwordHash = try await app.password.async.hash("password123")
        let identifier = Identifier.phone("+1234567890")
        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)

        // Create job payload
        let payload = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: "123456",
            userId: user.id!.description
        )

        // Create queue context
        let capturingLogger = CapturingLogger()
        let context = createMockQueueContext(app: app, logger: capturingLogger)

        // Execute the job and expect it to throw
        let job = Passage.Restoration.SendPhonePasswordResetCodeJob()
        await #expect(throws: MockDeliveryError.self) {
            try await job.dequeue(context, payload)
        }
    }

    // MARK: - Job Conformance Tests

    @Test
    func `SendEmailPasswordResetCodeJob conforms to AsyncJob`() {
        let job = Passage.Restoration.SendEmailPasswordResetCodeJob()
        let _: any AsyncJob = job
        #expect(Passage.Restoration.SendEmailPasswordResetCodeJob.self is any AsyncJob.Type)
    }

    @Test
    func `SendPhonePasswordResetCodeJob conforms to AsyncJob`() {
        let job = Passage.Restoration.SendPhonePasswordResetCodeJob()
        let _: any AsyncJob = job
        #expect(Passage.Restoration.SendPhonePasswordResetCodeJob.self is any AsyncJob.Type)
    }

    @Test
    func `SendEmailPasswordResetCodeJob has correct payload type`() {
        #expect(
            Passage.Restoration.SendEmailPasswordResetCodeJob.Payload.self
                == Passage.Restoration.EmailPasswordResetCodePayload.self
        )
    }

    @Test
    func `SendPhonePasswordResetCodeJob has correct payload type`() {
        #expect(
            Passage.Restoration.SendPhonePasswordResetCodeJob.Payload.self
                == Passage.Restoration.PhonePasswordResetCodePayload.self
        )
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test
    func `EmailPasswordResetCodePayload conforms to Sendable`() {
        assertSendable(Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: "user123",
            resetURL: URL(string: "https://example.com/reset")!,
            resetCode: "123456"
        ))
    }

    @Test
    func `SendEmailPasswordResetCodeJob conforms to Sendable`() {
        assertSendable(Passage.Restoration.SendEmailPasswordResetCodeJob())
    }

    @Test
    func `PhonePasswordResetCodePayload conforms to Sendable`() {
        assertSendable(Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: "123456",
            userId: "user123"
        ))
    }

    @Test
    func `SendPhonePasswordResetCodeJob conforms to Sendable`() {
        assertSendable(Passage.Restoration.SendPhonePasswordResetCodeJob())
    }
}

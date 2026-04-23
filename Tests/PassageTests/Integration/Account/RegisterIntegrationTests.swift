import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting
import XCTQueues

@Suite(.tags(.integration, .register))
struct `Register Integration Tests` {

    // MARK: - Sendable Capture Helper

    /// Helper class to capture sent emails/SMS in a Sendable-compliant way
    final class CapturedMessages: @unchecked Sendable {
        var emails: [Passage.OnlyForTest.MockEmailDelivery.EphemeralEmail] = []
        var sms: [Passage.OnlyForTest.MockPhoneDelivery.EphemeralSMS] = []
    }

    // MARK: - Configuration Helper

    /// Configures a test Vapor application with Passage
    @Sendable private func configure(_ app: Application) async throws {
        try await configureWithCapture(app, captured: nil)
    }

    /// Configures a test Vapor application with Passage and message capture
    @Sendable private func configureWithCapture(
        _ app: Application,
        captured: CapturedMessages?
    ) async throws {
        // Add HMAC key directly for testing (simpler than RSA)
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        app.queues.use(.asyncTest)

        // Configure Passage with test services
        let store = Passage.OnlyForTest.InMemoryStore()
        let emailCallback: (@Sendable (Passage.OnlyForTest.MockEmailDelivery.EphemeralEmail) -> Void)? = captured != nil ? { @Sendable in captured!.emails.append($0) } : nil
        let phoneCallback: (@Sendable (Passage.OnlyForTest.MockPhoneDelivery.EphemeralSMS) -> Void)? = captured != nil ? { @Sendable in captured!.sms.append($0) } : nil
        let emailDelivery = Passage.OnlyForTest.MockEmailDelivery(callback: emailCallback)
        let phoneDelivery = Passage.OnlyForTest.MockPhoneDelivery(callback: phoneCallback)

        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: emailDelivery,
            phoneDelivery: phoneDelivery,
            federatedLogin: nil
        )

        // Use empty JWKS since we're adding keys manually
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
            jwt: .init(jwks: .init(json: emptyJwks)),
            verification: .init(
                email: .init(
                    codeLength: 6,
                    codeExpiration: 600,
                    maxAttempts: 5
                ),
                phone: .init(
                    codeLength: 6,
                    codeExpiration: 600,
                    maxAttempts: 5
                ),
                useQueues: true
            ),
            restoration: .init(
                email: .init(
                    codeLength: 6,
                    codeExpiration: 600,
                    maxAttempts: 5
                ),
                phone: .init(
                    codeLength: 6,
                    codeExpiration: 600,
                    maxAttempts: 5
                ),
                useQueues: true
            )
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )
    }

    // MARK: - Successful Registration Tests

    @Test
    func `Registration succeeds with email identifier`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Register new user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "email": "newuser@example.com",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                // Verify user was created
                let store = app.passage.storage.services.store
                let user = try await store.users.find(
                    byIdentifier: Identifier.email( "newuser@example.com")
                )

                #expect(user != nil)
                #expect(user?.email == "newuser@example.com")
                #expect(user?.isEmailVerified == false)
            })

            // Run queue worker to process verification email job
            try await app.queues.queue.worker.run()

            // Verify verification email was sent
            #expect(captured.emails.count == 1)
            #expect(captured.emails.first?.to == "newuser@example.com")
            #expect(captured.emails.first?.type == .verification)
            #expect(captured.emails.first?.verificationCode != nil)
        }
    }

    @Test
    func `Registration succeeds with phone identifier`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Register new user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                // Verify user was created
                let store = app.passage.storage.services.store
                let user = try await store.users.find(
                    byIdentifier: Identifier.phone( "+1234567890")
                )

                #expect(user != nil)
                #expect(user?.phone == "+1234567890")
                #expect(user?.isPhoneVerified == false)
            })

            // Run queue worker to process verification SMS job
            try await app.queues.queue.worker.run()

            // Verify SMS was sent
            #expect(captured.sms.count == 1)
            #expect(captured.sms.first?.to == "+1234567890")
            #expect(captured.sms.first?.type == .verification)
            #expect(captured.sms.first?.code != nil)
        }
    }

    @Test
    func `Registration succeeds with username identifier`() async throws {
        try await withApp(configure: configure) { app in
            // Register new user with username
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "testuser",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                // Verify user was created
                let store = app.passage.storage.services.store
                let user = try await store.users.find(
                    byIdentifier: Identifier.username( "testuser")
                )

                #expect(user != nil)
                #expect(user?.username == "testuser")
                // Username doesn't require verification
                #expect(user?.isEmailVerified == false)
                #expect(user?.isPhoneVerified == false)
            })
        }
    }

    // MARK: - Duplicate Identifier Tests

    @Test
    func `Registration fails when email already exists`() async throws {
        try await withApp(configure: configure) { app in
            // Create first user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "email": "existing@example.com",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Attempt to register with same email
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "email": "existing@example.com",
                    "password": "password456",
                    "confirmPassword": "password456"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .conflict)
            })
        }
    }

    @Test
    func `Registration fails when phone already exists`() async throws {
        try await withApp(configure: configure) { app in
            // Create first user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Attempt to register with same phone
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password456",
                    "confirmPassword": "password456"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .conflict)
            })
        }
    }

    @Test
    func `Registration fails when username already exists`() async throws {
        try await withApp(configure: configure) { app in
            // Create first user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "testuser",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Attempt to register with same username
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "testuser",
                    "password": "password456",
                    "confirmPassword": "password456"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .conflict)
            })
        }
    }

    // MARK: - Form Validation Tests

    @Test
    func `Registration fails when passwords don't match`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "password": "password123",
                    "confirmPassword": "different_password"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test
    func `Registration fails when no identifier provided`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    // MARK: - Verification Flow Tests

    @Test
    func `User cannot login with unverified email`() async throws {
        try await withApp(configure: configure) { app in
            // Register user with email
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "email": "unverified@example.com",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Attempt to login without verifying
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "unverified@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
        }
    }

    @Test
    func `User cannot login with unverified phone`() async throws {
        try await withApp(configure: configure) { app in
            // Register user with phone
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Attempt to login without verifying
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
        }
    }

    @Test
    func `Username registration allows immediate login`() async throws {
        try await withApp(configure: configure) { app in
            // Register user with username
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "username": "testuser",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            // Login immediately (no verification required for username)
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "username": "testuser",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(!authUser.accessToken.isEmpty)
                #expect(!authUser.refreshToken.isEmpty)
            })
        }
    }

    // MARK: - Email Verification Tests

    @Test
    func `Email verification succeeds via GET request with code`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Register user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "email": "verify@example.com",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                // Verify user was created
                let store = app.passage.storage.services.store
                let user = try await store.users.find(
                    byIdentifier: Identifier.email( "verify@example.com")
                )
                #expect(user != nil)
            })

            // Run queue worker to process verification email job
            try await app.queues.queue.worker.run()

            // Verify verification email was sent
            #expect(captured.emails.count == 1)

            // Verify email with code (no auth required)
            try await app.testing().test(
                .GET,
                "auth/email/verify?code=\(captured.emails.first!.verificationCode!)&email=\(captured.emails.first!.to)",
                afterResponse: { res async throws in
                    #expect(res.status == .ok)

                    // Verify user is now marked as verified
                    let store = app.passage.storage.services.store
                    let user = try await store.users.find(
                        byIdentifier: Identifier.email( "verify@example.com")
                    )
                    #expect(user?.isEmailVerified == true)
                }
            )
        }
    }

    @Test
    func `Email verification fails with invalid code`() async throws {
        try await withApp(configure: configure) { app in
            // Register user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "email": "verify@example.com",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
            })

            // Attempt verification with wrong code (no auth required)
            try await app.testing().test(
                .GET,
                "auth/email/verify?code=WRONGCODE&email=verify@example.com",
                afterResponse: { res async in
                    #expect(res.status == .unauthorized)
                }
            )
        }
    }

    @Test
    func `Verified email user can login successfully`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Register user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "email": "verified@example.com",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
            })

            // Run queue worker to process verification email job
            try await app.queues.queue.worker.run()

            // Verify email (no auth required)
            try await app.testing().test(
                .GET,
                "auth/email/verify?code=\(captured.emails.first!.verificationCode!)&email=verified@example.com",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                }
            )

            // Now login should succeed
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": "verified@example.com",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(!authUser.accessToken.isEmpty)
                #expect(authUser.user.email == "verified@example.com")
            })
        }
    }

    // MARK: - Phone Verification Tests

    @Test
    func `Phone verification succeeds via POST request with code`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Register user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                // Verify user was created
                let store = app.passage.storage.services.store
                let user = try await store.users.find(
                    byIdentifier: Identifier.phone( "+1234567890")
                )
                #expect(user != nil)
            })

            try await app.queues.queue.worker.run()

            // Verify phone with POST request (no auth required, uses query params)
            // Note: + must be encoded as %2B in query strings (urlQueryAllowed doesn't encode it)
            let phone = "+1234567890".addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
            try await app.testing().test(
                .POST,
                "auth/phone/verify?code=\(captured.sms.first!.code!)&phone=\(phone)",
                afterResponse: { res async throws in
                    #expect(res.status == .ok)

                    // Verify user is now marked as verified
                    let store = app.passage.storage.services.store
                    let user = try await store.users.find(
                        byIdentifier: Identifier.phone( "+1234567890")
                    )
                    #expect(user?.isPhoneVerified == true)
                }
            )
        }
    }

    @Test
    func `Phone verification fails with invalid code`() async throws {
        try await withApp(configure: configure) { app in
            // Register user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
            })

            // Attempt verification with wrong code (no auth required, uses query params)
            // Note: + must be encoded as %2B in query strings (urlQueryAllowed doesn't encode it)
            let phone = "+1234567890".addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
            try await app.testing().test(
                .POST,
                "auth/phone/verify?code=WRONGCODE&phone=\(phone)",
                afterResponse: { res async in
                    #expect(res.status == .unauthorized)
                }
            )
        }
    }

    @Test
    func `Verified phone user can login successfully`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Register user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
            })

            // Run queue worker to process verification SMS job
            try await app.queues.queue.worker.run()

            // Verify phone (no auth required, uses query params)
            // Note: + must be encoded as %2B in query strings (urlQueryAllowed doesn't encode it)
            let phone = "+1234567890".addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
            try await app.testing().test(
                .POST,
                "auth/phone/verify?code=\(captured.sms.first!.code!)&phone=\(phone)",
                afterResponse: { res async in
                    #expect(res.status == .ok)
                }
            )

            // Now login should succeed
            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let authUser = try res.content.decode(AuthUser.self)
                #expect(!authUser.accessToken.isEmpty)
                #expect(authUser.user.phone == "+1234567890")
            })
        }
    }

    // MARK: - Verification Code Resend Tests

    @Test
    func `Email verification code can be resent`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Register user (sends first code)
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "email": "resend@example.com",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
            })

            // Run queue worker to process first verification email
            try await app.queues.queue.worker.run()
            #expect(captured.emails.count == 1)

            // Resend verification code (no auth required, email in body)
            try await app.testing().test(
                .POST,
                "auth/email/resend",
                beforeRequest: { req in
                    try req.content.encode(["email": "resend@example.com"])
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                }
            )

            // Run queue worker to process resend email
            try await app.queues.queue.worker.run()
            #expect(captured.emails.count == 2)
            #expect(captured.emails.last?.verificationCode != nil)
        }
    }

    @Test
    func `Phone verification code can be resent`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            // Register user (sends first code)
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode([
                    "phone": "+1234567890",
                    "password": "password123",
                    "confirmPassword": "password123"
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
            })

            // Run queue worker to process first verification SMS
            try await app.queues.queue.worker.run()
            #expect(captured.sms.count == 1)

            // Resend verification code (no auth required, phone in body)
            try await app.testing().test(
                .POST,
                "auth/phone/resend",
                beforeRequest: { req in
                    try req.content.encode(["phone": "+1234567890"])
                },
                afterResponse: { res async in
                    #expect(res.status == .ok)
                }
            )

            // Run queue worker to process resend SMS
            try await app.queues.queue.worker.run()
            #expect(captured.sms.count == 2)
            #expect(captured.sms.last?.code != nil)
        }
    }
}

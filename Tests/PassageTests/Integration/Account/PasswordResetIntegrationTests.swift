import JWT
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting
import XCTQueues

@Suite(.tags(.integration, .resetPassword))
struct `Password Reset Integration Tests` {

    // MARK: - Helpers

    /// Helper class to capture sent emails and SMS
    final class CapturedMessages: @unchecked Sendable {
        var emails: [Passage.OnlyForTest.MockEmailDelivery.EphemeralEmail] = []
        var sms: [Passage.OnlyForTest.MockPhoneDelivery.EphemeralSMS] = []
    }

    // MARK: - Configuration Helpers

    /// Configures a test Vapor application with Passage
    @Sendable private func configure(_ app: Application) async throws {
        try await configureWithCapture(app, captured: nil, codeExpiration: 600)
    }

    /// Configures a test Vapor application with Passage and optional message capture
    @Sendable private func configureWithCapture(
        _ app: Application,
        captured: CapturedMessages? = nil,
        codeExpiration: TimeInterval = 600
    ) async throws {
        // Add HMAC key directly for testing
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        app.queues.use(.asyncTest)

        // Configure Passage with test services
        let store = Passage.OnlyForTest.InMemoryStore()

        let emailCallback: (@Sendable (Passage.OnlyForTest.MockEmailDelivery.EphemeralEmail) -> Void)? =
            captured != nil ? { @Sendable in captured!.emails.append($0) } : nil
        let phoneCallback: (@Sendable (Passage.OnlyForTest.MockPhoneDelivery.EphemeralSMS) -> Void)? =
            captured != nil ? { @Sendable in captured!.sms.append($0) } : nil

        let emailDelivery = Passage.OnlyForTest.MockEmailDelivery(callback: emailCallback)
        let phoneDelivery = Passage.OnlyForTest.MockPhoneDelivery(callback: phoneCallback)

        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: emailDelivery,
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
            jwt: .init(jwks: .init(json: emptyJwks)),
            verification: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: true
            ),
            restoration: .init(
                email: .init(codeLength: 6, codeExpiration: codeExpiration, maxAttempts: 3),
                phone: .init(codeLength: 6, codeExpiration: codeExpiration, maxAttempts: 3),
                useQueues: true
            )
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )
    }

    /// Creates a test user directly in the store
    @Sendable private func createTestUser(
        app: Application,
        email: String? = nil,
        phone: String? = nil,
        username: String? = nil,
        password: String = "oldPassword123",
        isEmailVerified: Bool = false,
        isPhoneVerified: Bool = false
    ) async throws {
        let store = app.passage.storage.services.store
        let passwordHash = try await app.password.async.hash(password)

        let identifier: Identifier
        if let email = email {
            identifier = .email(email)
        } else if let phone = phone {
            identifier = .phone(phone)
        } else if let username = username {
            identifier = .username(username)
        } else {
            fatalError("Must provide at least one identifier")
        }

        let credential = Credential.password(passwordHash)
        let user = try await store.users.create(identifier: identifier, with: credential)

        // Update verification status if needed
        if isEmailVerified {
            try await store.users.markEmailVerified(for: user)
        }
        if isPhoneVerified {
            try await store.users.markPhoneVerified(for: user)
        }
    }

    // MARK: - Helper Methods



    // MARK: - Email Password Reset Tests

    @Test
    func `Request password reset via email sends reset code`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            let email = "user@example.com"
            try await createTestUser(app: app, email: email)

            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            try await app.queues.queue.worker.run()

            #expect(captured.emails.count == 1)

            let sentEmail = try #require(captured.emails.first)
            #expect(sentEmail.to == email)
            #expect(sentEmail.passwordResetCode != nil)
            #expect(sentEmail.passwordResetURL != nil)
        }
    }

    @Test
    func `Request password reset via phone sends SMS code`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            let phone = "+1234567890"
            try await createTestUser(app: app, phone: phone)

            try await app.testing().test(.POST, "/auth/password/reset/phone", beforeRequest: { req in
                try req.content.encode(["phone": phone])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            try await app.queues.queue.worker.run()

            #expect(captured.sms.count == 1)

            let sentSMS = try #require(captured.sms.first)
            #expect(sentSMS.to == phone)
            #expect(sentSMS.code != nil)
        }
    }

    @Test
    func `Successful password reset via email with valid code`() async throws {
        let captured = CapturedMessages()
        let email = "user@example.com"
        let oldPassword = "oldPassword123"
        let newPassword = "newPassword456"

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            try await createTestUser(app: app, email: email, password: oldPassword, isEmailVerified: true)

            // Step 1: Request password reset code
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            try await app.queues.queue.worker.run()

            let resetCode = try #require(captured.emails.first?.passwordResetCode)

            // Step 2: Verify code and reset password
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "code": resetCode,
                    "newPassword": newPassword
                ])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Step 3: Verify old password no longer works
            try await app.testing().test(.POST, "/auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "password": oldPassword
                ])
            }, afterResponse: { res in
                #expect(res.status == .unauthorized)
            })

            // Step 4: Verify new password works
            try await app.testing().test(.POST, "/auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "password": newPassword
                ])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    @Test
    func `Successful password reset via phone with valid code`() async throws {
        let captured = CapturedMessages()
        let phone = "+1234567890"
        let oldPassword = "oldPassword123"
        let newPassword = "newPassword456"

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            try await createTestUser(app: app, phone: phone, password: oldPassword, isPhoneVerified: true)

            // Step 1: Request password reset code
            try await app.testing().test(.POST, "/auth/password/reset/phone", beforeRequest: { req in
                try req.content.encode(["phone": phone])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            try await app.queues.queue.worker.run()

            let resetCode = try #require(captured.sms.first?.code)

            // Step 2: Verify code and reset password
            try await app.testing().test(.POST, "/auth/password/reset/phone/verify", beforeRequest: { req in
                try req.content.encode([
                    "phone": phone,
                    "code": resetCode,
                    "newPassword": newPassword
                ])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Step 3: Verify old password no longer works
            try await app.testing().test(.POST, "/auth/login", beforeRequest: { req in
                try req.content.encode([
                    "phone": phone,
                    "password": oldPassword
                ])
            }, afterResponse: { res in
                #expect(res.status == .unauthorized)
            })

            // Step 4: Verify new password works
            try await app.testing().test(.POST, "/auth/login", beforeRequest: { req in
                try req.content.encode([
                    "phone": phone,
                    "password": newPassword
                ])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    @Test
    func `Password reset fails with invalid code`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            let email = "user@example.com"
            try await createTestUser(app: app, email: email)

            // Request reset code
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Try to verify with wrong code
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "code": "wrongcode",
                    "newPassword": "newPassword456"
                ])
            }, afterResponse: { res in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Password reset fails with expired code`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in
            // Set code to expire immediately
            try await configureWithCapture(app, captured: captured, codeExpiration: -1)
        }) { app in
            let email = "user@example.com"
            try await createTestUser(app: app, email: email)

            // Request reset code
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Run queue worker to process password reset email
            try await app.queues.queue.worker.run()

            let resetCode = try #require(captured.emails.first?.passwordResetCode)

            // Try to verify with expired code
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "code": resetCode,
                    "newPassword": "newPassword456"
                ])
            }, afterResponse: { res in
                #expect(res.status == .gone)
            })
        }
    }

    @Test
    func `Password reset request fails for non-existent email`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": "nonexistent@example.com"])
            }, afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test
    func `Password reset request fails for non-existent phone`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "/auth/password/reset/phone", beforeRequest: { req in
                try req.content.encode(["phone": "+9999999999"])
            }, afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test
    func `Email password reset link URL contains code and email`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            let email = "user@example.com"
            try await createTestUser(app: app, email: email)

            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Run queue worker to process password reset email
            try await app.queues.queue.worker.run()

            let sentEmail = try #require(captured.emails.first)
            let resetURL = try #require(sentEmail.passwordResetURL)
            let resetCode = try #require(sentEmail.passwordResetCode)

            // Verify URL structure
            #expect(resetURL.absoluteString.contains("password/reset/email/verify"))
            #expect(resetURL.absoluteString.contains("code=\(resetCode)"))
            #expect(resetURL.absoluteString.contains("email="))
        }
    }

    @Test
    func `Resend email password reset code invalidates old code`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            let email = "user@example.com"
            try await createTestUser(app: app, email: email)

            // Request initial reset code
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Run queue worker to process first reset email
            try await app.queues.queue.worker.run()

            let firstCode = try #require(captured.emails.first?.passwordResetCode)

            // Resend reset code
            try await app.testing().test(.POST, "/auth/password/reset/email/resend", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Run queue worker to process resend email
            try await app.queues.queue.worker.run()

            #expect(captured.emails.count == 2)
            let secondCode = try #require(captured.emails.last?.passwordResetCode)
            #expect(firstCode != secondCode)

            // Try to use old code - should fail
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "code": firstCode,
                    "newPassword": "newPassword456"
                ])
            }, afterResponse: { res in
                #expect(res.status == .unauthorized)
            })

            // Use new code - should succeed
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "code": secondCode,
                    "newPassword": "newPassword456"
                ])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    @Test
    func `Resend phone password reset code invalidates old code`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            let phone = "+1234567890"
            try await createTestUser(app: app, phone: phone)

            // Request initial reset code
            try await app.testing().test(.POST, "/auth/password/reset/phone", beforeRequest: { req in
                try req.content.encode(["phone": phone])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Run queue worker to process first reset SMS
            try await app.queues.queue.worker.run()

            let firstCode = try #require(captured.sms.first?.code)

            // Resend reset code
            try await app.testing().test(.POST, "/auth/password/reset/phone/resend", beforeRequest: { req in
                try req.content.encode(["phone": phone])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Run queue worker to process resend SMS
            try await app.queues.queue.worker.run()

            #expect(captured.sms.count == 2)
            let secondCode = try #require(captured.sms.last?.code)
            #expect(firstCode != secondCode)

            // Try to use old code - should fail
            try await app.testing().test(.POST, "/auth/password/reset/phone/verify", beforeRequest: { req in
                try req.content.encode([
                    "phone": phone,
                    "code": firstCode,
                    "newPassword": "newPassword456"
                ])
            }, afterResponse: { res in
                #expect(res.status == .unauthorized)
            })

            // Use new code - should succeed
            try await app.testing().test(.POST, "/auth/password/reset/phone/verify", beforeRequest: { req in
                try req.content.encode([
                    "phone": phone,
                    "code": secondCode,
                    "newPassword": "newPassword456"
                ])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })
        }
    }

    @Test
    func `Password reset invalidates code after successful use`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            let email = "user@example.com"
            try await createTestUser(app: app, email: email)

            // Request reset code
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Run queue worker to process password reset email
            try await app.queues.queue.worker.run()

            let resetCode = try #require(captured.emails.first?.passwordResetCode)

            // Use code to reset password
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "code": resetCode,
                    "newPassword": "newPassword456"
                ])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Try to reuse the same code - should fail
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "code": resetCode,
                    "newPassword": "anotherPassword789"
                ])
            }, afterResponse: { res in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test
    func `Password reset request fails with invalid email format`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": "invalid-email"])
            }, afterResponse: { res in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test
    func `Password reset verify fails with missing fields`() async throws {
        try await withApp(configure: configure) { app in
            // Missing newPassword
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "code": "123456"
                ])
            }, afterResponse: { res in
                #expect(res.status == .badRequest)
            })

            // Missing code
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": "user@example.com",
                    "newPassword": "newPassword123"
                ])
            }, afterResponse: { res in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test
    func `Password reset verify fails with short password`() async throws {
        let captured = CapturedMessages()

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            let email = "user@example.com"
            try await createTestUser(app: app, email: email)

            // Request reset code
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Run queue worker to process password reset email
            try await app.queues.queue.worker.run()

            let resetCode = try #require(captured.emails.first?.passwordResetCode)

            // Try to reset with password that's too short (< 6 characters)
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "code": resetCode,
                    "newPassword": "short"
                ])
            }, afterResponse: { res in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test
    func `Password reset revokes all refresh tokens`() async throws {
        let captured = CapturedMessages()
        let email = "user@example.com"
        let oldPassword = "oldPassword123"
        let newPassword = "newPassword456"
        var refreshToken = ""

        try await withApp(configure: { app in try await configureWithCapture(app, captured: captured) }) { app in
            try await createTestUser(app: app, email: email, password: oldPassword, isEmailVerified: true)

            // Step 1: Login to get a refresh token
            try await app.testing().test(.POST, "/auth/login", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "password": oldPassword
                ])
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let authUser = try res.content.decode(AuthUser.self)
                refreshToken = authUser.refreshToken
            })

            // Step 2: Request password reset code
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Run queue worker to process password reset email
            try await app.queues.queue.worker.run()

            let resetCode = try #require(captured.emails.first?.passwordResetCode)

            // Step 3: Reset password (should revoke all refresh tokens)
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", beforeRequest: { req in
                try req.content.encode([
                    "email": email,
                    "code": resetCode,
                    "newPassword": newPassword
                ])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Step 4: Try to use old refresh token - should fail
            try await app.testing().test(.POST, "/auth/refresh-token", beforeRequest: { req in
                try req.content.encode(["refreshToken": refreshToken])
            }, afterResponse: { res in
                #expect(res.status == .unauthorized)
            })
        }
    }
}

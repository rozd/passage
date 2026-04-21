import JWT
import Leaf
import LeafKit
@testable import Passage
@testable import PassageOnlyForTest
import Queues
import Testing
import Vapor
import VaporTesting
import XCTQueues

@Suite(.tags(.integration))
struct `Views Integration Tests` {

    // MARK: - Helpers

    /// Helper class to capture sent emails and SMS
    final class CapturedMessages: @unchecked Sendable {
        var emails: [Passage.OnlyForTest.MockEmailDelivery.EphemeralEmail] = []
        var sms: [Passage.OnlyForTest.MockPhoneDelivery.EphemeralSMS] = []
    }

    // MARK: - Configuration Helpers

    /// Configures a test Vapor application with Passage
    @Sendable private func configure(
        _ app: Application,
        viewsConfig: Passage.Configuration.Views,
        captureRenderer: CapturingViewRenderer? = nil,
        captured: CapturedMessages? = nil
    ) async throws {
        // Use capturing renderer if provided (for view rendering tests)
        // Otherwise use default (for 404 tests)
        if let renderer = captureRenderer {
            app.views.use { req in
                renderer
            }
        }

        // Add HMAC key for JWT
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

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

        // Configure queues for tests that need passwordless
        app.queues.use(.asyncTest)

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            routes: .init(),
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: emptyJwks)),
            passwordless: .init(
                emailMagicLink: .email(useQueues: true)
            ),
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
                useQueues: false
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
                useQueues: false
            ),
            views: viewsConfig
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )
    }

    // MARK: - Login View 404 Tests

    @Test
    func `Login view returns 404 when not configured`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            try await app.testing().test(.GET, "/auth/login", afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Login View Rendering Tests

    @Test
    func `Login view renders login-minimalism template with email identifier`() async throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: theme,
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(login: loginView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/login", afterResponse: { res in
                #expect(res.status == .ok)

                // Verify correct template was requested
                #expect(renderer.templatePath == "login-minimalism")

                // Verify context was passed
                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.LoginViewParams>
                #expect(ctx?.params.byEmail == true)
                #expect(ctx?.params.byPhone == false)
                #expect(ctx?.params.byUsername == false)
            })
        }
    }

    @Test
    func `Login view renders with phone identifier context`() async throws {
        let theme = Passage.Views.Theme(colors: .oceanLight)
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: theme,
            identifier: .phone
        )
        let viewsConfig = Passage.Configuration.Views(login: loginView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/login", afterResponse: { res in
                #expect(res.status == .ok)

                #expect(renderer.templatePath == "login-minimalism")

                // Verify context was passed
                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.LoginViewParams>
                #expect(ctx?.params.byEmail == false)
                #expect(ctx?.params.byPhone == true)
                #expect(ctx?.params.byUsername == false)
            })
        }
    }

    @Test
    func `Login view captures query parameters in context`() async throws {
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(login: loginView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/login?error=Invalid+credentials", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "login-minimalism")
                // Context contains error parameter

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.LoginViewParams>
                #expect(ctx?.params.error == "Invalid credentials")
            })
        }
    }

    // MARK: - Login Form Submission Tests

    @Test
    func `Login form submission succeeds and redirects to login page with success message`() async throws {
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(login: loginView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            // Create a verified user first
            let email = "test@example.com"
            let password = "SecurePassword123!"
            let passwordHash = try await app.password.async.hash(password)

            let identifier = Identifier.email(email)
            let credential = Credential.password(passwordHash)
            let store = app.passage.storage.services.store
            let user = try await store.users.create(identifier: identifier, with: credential)

            // Mark email as verified
            try await store.users.markEmailVerified(for: user)

            // Submit login form with correct credentials
            try await app.testing().test(.POST, "/auth/login", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)&password=\(password)&confirmPassword=\(password)"), afterResponse: { res in
                // Should redirect (302 or 303)
                #expect(res.status == .seeOther || res.status == .found)

                // Should have Location header
                let location = res.headers.first(name: .location)
                #expect(location != nil)

                // Should redirect back to login with success message
                #expect(location?.contains("/auth/login") == true)
                #expect(location?.contains("success=") == true)
                // Success message contains "successfully logged in"
                #expect(location?.contains("successfully") == true || location?.contains("logged+in") == true)
            })
        }
    }

    @Test
    func `Login form submission fails and redirects to login page with error message`() async throws {
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(login: loginView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            // Submit login form with incorrect credentials (no user exists)
            try await app.testing().test(.POST, "/auth/login", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=nonexistent@example.com&password=wrongpassword"), afterResponse: { res in
                // Should redirect (302 or 303)
                #expect(res.status == .seeOther || res.status == .found)

                // Should have Location header
                let location = res.headers.first(name: .location)
                #expect(location != nil)

                // Should redirect back to login with error message
                #expect(location?.contains("/auth/login") == true)
                #expect(location?.contains("error=") == true)
            })
        }
    }

    @Test
    func `Login form submission with custom redirect on success`() async throws {
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: "/dashboard",
            onFailure: nil
        )
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: redirect,
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(login: loginView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            // Create a verified user first
            let email = "test@example.com"
            let password = "SecurePassword123!"
            let passwordHash = try await app.password.async.hash(password)

            let identifier = Identifier.email(email)
            let credential = Credential.password(passwordHash)
            let store = app.passage.storage.services.store
            let user = try await store.users.create(identifier: identifier, with: credential)

            // Mark email as verified
            try await store.users.markEmailVerified(for: user)

            // Submit login form with correct credentials
            try await app.testing().test(.POST, "/auth/login", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)&password=\(password)&confirmPassword=\(password)"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should redirect to custom success location
                let location = res.headers.first(name: .location)
                #expect(location == "/dashboard")
            })
        }
    }

    @Test
    func `Login form submission with custom redirect on failure`() async throws {
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: nil,
            onFailure: "/error"
        )
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: redirect,
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(login: loginView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            // Submit login form with incorrect credentials
            try await app.testing().test(.POST, "/auth/login", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=nonexistent@example.com&password=wrongpassword"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should redirect to custom failure location
                let location = res.headers.first(name: .location)
                #expect(location == "/error")
            })
        }
    }

    // MARK: - Register View 404 Tests

    @Test
    func `Register view returns 404 when not configured`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            try await app.testing().test(.GET, "/auth/register", afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Register View Rendering Tests

    @Test
    func `Register view renders register-minimalism template with email identifier`() async throws {
        let registerView = Passage.Configuration.Views.RegisterView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(register: registerView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/register", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "register-minimalism")

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.RegisterViewParams>
                #expect(ctx?.params.byEmail == true)
                #expect(ctx?.params.byPhone == false)
                #expect(ctx?.params.byUsername == false)
            })
        }
    }

    @Test
    func `Register view renders register-neobrutalism template with phone identifier`() async throws {
        let registerView = Passage.Configuration.Views.RegisterView(
            style: .neobrutalism,
            theme: Passage.Views.Theme(colors: .oceanLight),
            identifier: .phone
        )
        let viewsConfig = Passage.Configuration.Views(register: registerView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/register", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "register-neobrutalism")

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.RegisterViewParams>
                #expect(ctx?.params.byEmail == false)
                #expect(ctx?.params.byPhone == true)
                #expect(ctx?.params.byUsername == false)
            })
        }
    }

    // MARK: - Register Form Submission Tests

    @Test
    func `Register form submission succeeds and redirects to register page with success message`() async throws {
        let registerView = Passage.Configuration.Views.RegisterView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(register: registerView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            let email = "newuser-\(UUID().uuidString)@example.com"
            let password = "SecurePassword123!"

            // Submit register form
            try await app.testing().test(.POST, "/auth/register", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)&password=\(password)&confirmPassword=\(password)"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should have Location header
                let location = res.headers.first(name: .location)
                #expect(location != nil)

                // Should redirect back to register with success message
                #expect(location?.contains("/auth/register") == true)
                #expect(location?.contains("success=") == true)
                #expect(location?.contains("successfully") == true || location?.contains("registered") == true)
            })
        }
    }

    @Test
    func `Register form submission fails and redirects to register page with error message`() async throws {
        let registerView = Passage.Configuration.Views.RegisterView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(register: registerView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            // Create an existing user first
            let email = "existing@example.com"
            let password = "SecurePassword123!"
            let passwordHash = try await app.password.async.hash(password)
            let identifier = Identifier.email(email)
            let credential = Credential.password(passwordHash)
            let store = app.passage.storage.services.store
            _ = try await store.users.create(identifier: identifier, with: credential)

            // Try to register with same email (should fail)
            try await app.testing().test(.POST, "/auth/register", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)&password=\(password)&confirmPassword=\(password)"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should have Location header
                let location = res.headers.first(name: .location)
                #expect(location != nil)

                // Should redirect back to register with error message
                #expect(location?.contains("/auth/register") == true)
                #expect(location?.contains("error=") == true)
            })
        }
    }

    @Test
    func `Register form submission with custom redirect on success`() async throws {
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: "/welcome",
            onFailure: nil
        )
        let registerView = Passage.Configuration.Views.RegisterView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: redirect,
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(register: registerView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            let email = "newuser-\(UUID().uuidString)@example.com"
            let password = "SecurePassword123!"

            // Submit register form
            try await app.testing().test(.POST, "/auth/register", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)&password=\(password)&confirmPassword=\(password)"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should redirect to custom success location
                let location = res.headers.first(name: .location)
                #expect(location == "/welcome")
            })
        }
    }

    @Test
    func `Register form submission with custom redirect on failure`() async throws {
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: nil,
            onFailure: "/signup-error"
        )
        let registerView = Passage.Configuration.Views.RegisterView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: redirect,
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(register: registerView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            // Create an existing user first
            let email = "existing@example.com"
            let password = "SecurePassword123!"
            let passwordHash = try await app.password.async.hash(password)
            let identifier = Identifier.email(email)
            let credential = Credential.password(passwordHash)
            let store = app.passage.storage.services.store
            _ = try await store.users.create(identifier: identifier, with: credential)

            // Try to register with same email
            try await app.testing().test(.POST, "/auth/register", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)&password=\(password)&confirmPassword=\(password)"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should redirect to custom failure location
                let location = res.headers.first(name: .location)
                #expect(location == "/signup-error")
            })
        }
    }

    // MARK: - Password Reset Request View 404 Tests

    @Test
    func `Password reset request view returns 404 when not configured for email`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            try await app.testing().test(.GET, "/auth/password/reset/email", afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test
    func `Password reset request view returns 404 when not configured for phone`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            try await app.testing().test(.GET, "/auth/password/reset/phone", afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Password Reset Request View Rendering Tests

    @Test
    func `Password reset request view renders for email`() async throws {
        let resetView = Passage.Configuration.Views.PasswordResetRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(passwordResetRequest: resetView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/password/reset/email", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "password-reset-request-minimalism")

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.ResetPasswordRequestViewParams>
                #expect(ctx?.params.byEmail == true)
                #expect(ctx?.params.byPhone == false)
            })
        }
    }

    @Test
    func `Password reset request view renders with material style for phone`() async throws {
        let resetView = Passage.Configuration.Views.PasswordResetRequestView(
            style: .material,
            theme: Passage.Views.Theme(colors: .forestLight)
        )
        let viewsConfig = Passage.Configuration.Views(passwordResetRequest: resetView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/password/reset/phone", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "password-reset-request-material")

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.ResetPasswordRequestViewParams>
                #expect(ctx?.params.byEmail == false)
                #expect(ctx?.params.byPhone == true)
            })
        }
    }

    // MARK: - Password Reset Request Form Submission Tests

    @Test
    func `Password reset request form submission succeeds for email`() async throws {
        let resetView = Passage.Configuration.Views.PasswordResetRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(passwordResetRequest: resetView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            // Create a user first
            let email = "user@example.com"
            let password = "SecurePassword123!"
            let passwordHash = try await app.password.async.hash(password)
            let identifier = Identifier.email(email)
            let credential = Credential.password(passwordHash)
            let store = app.passage.storage.services.store
            _ = try await store.users.create(identifier: identifier, with: credential)

            // Submit password reset request form
            try await app.testing().test(.POST, "/auth/password/reset/email", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should have Location header
                let location = res.headers.first(name: .location)
                #expect(location != nil)

                // Should redirect back with success message (generic for security)
                #expect(location?.contains("/auth/password/reset/email") == true)
                #expect(location?.contains("success=") == true)
            })
        }
    }

    @Test
    func `Password reset request form submission fails with invalid email format`() async throws {
        let resetView = Passage.Configuration.Views.PasswordResetRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(passwordResetRequest: resetView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            // Submit with invalid email format
            try await app.testing().test(.POST, "/auth/password/reset/email", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=invalid-email"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should have Location header with error
                let location = res.headers.first(name: .location)
                #expect(location != nil)
                #expect(location?.contains("/auth/password/reset/email") == true)
                #expect(location?.contains("error=") == true)
            })
        }
    }

    // MARK: - Password Reset Confirm View 404 Tests

    @Test
    func `Password reset confirm view returns 404 when not configured for email`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            try await app.testing().test(.GET, "/auth/password/reset/email/verify?code=123456", afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test
    func `Password reset confirm view returns 404 when not configured for phone`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            try await app.testing().test(.GET, "/auth/password/reset/phone/verify?code=123456", afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Password Reset Request View Rendering Tests

    @Test
    func `Password reset confirm view renders for email`() async throws {
        let resetView = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(passwordResetConfirm: resetView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/password/reset/email/verify?code=123456", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "password-reset-confirm-minimalism")

                let context = renderer.capturedContext as? Passage.Views.Context<Passage.Views.ResetPasswordConfirmViewParams>
                #expect(context?.params.byEmail == true)
                #expect(context?.params.byPhone == false)
            })
        }
    }

    @Test
    func `Password reset confirm view renders for phone`() async throws {
        let resetView = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(passwordResetConfirm: resetView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/password/reset/phone/verify?code=123456", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "password-reset-confirm-minimalism")

                let context = renderer.capturedContext as? Passage.Views.Context<Passage.Views.ResetPasswordConfirmViewParams>
                #expect(context?.params.byEmail == false)
                #expect(context?.params.byPhone == true)
            })
        }
    }

    // MARK: - Password Reset Confirm Form Submission Tests

    @Test
    func `Password reset confirm form submission succeeds for email`() async throws {
        let captured = CapturedMessages()
        let confirmView = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(passwordResetConfirm: confirmView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig, captured: captured)

            // Create a user
            let email = "user@example.com"
            let password = "OldPassword123!"
            let newPassword = "NewPassword456!"
            let passwordHash = try await app.password.async.hash(password)
            let identifier = Identifier.email(email)
            let credential = Credential.password(passwordHash)
            let store = app.passage.storage.services.store
            _ = try await store.users.create(identifier: identifier, with: credential)

            // Request password reset to get a code (via HTTP endpoint)
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Get the reset code from captured email
            let resetCode = try #require(captured.emails.first?.passwordResetCode)

            // Submit password reset confirm form
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)&code=\(resetCode)&newPassword=\(newPassword)"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should have Location header
                let location = res.headers.first(name: .location)
                #expect(location != nil)

                // Should redirect with success message
                #expect(location?.contains("/auth/password/reset/email/verify") == true)
                #expect(location?.contains("success=") == true)
            })
        }
    }

    @Test
    func `Password reset confirm form submission fails with invalid code`() async throws {
        let confirmView = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(passwordResetConfirm: confirmView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            // Create a user
            let email = "user@example.com"
            let password = "OldPassword123!"
            let passwordHash = try await app.password.async.hash(password)
            let identifier = Identifier.email(email)
            let credential = Credential.password(passwordHash)
            let store = app.passage.storage.services.store
            _ = try await store.users.create(identifier: identifier, with: credential)

            // Submit with invalid code
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)&code=INVALID&newPassword=NewPassword456!"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should have Location header with error
                let location = res.headers.first(name: .location)
                #expect(location != nil)
                #expect(location?.contains("/auth/password/reset/email/verify") == true)
                #expect(location?.contains("error=") == true)
            })
        }
    }

    @Test
    func `Password reset confirm form submission with custom redirect on success`() async throws {
        let captured = CapturedMessages()
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: "/login",
            onFailure: nil
        )
        let confirmView = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: redirect
        )
        let viewsConfig = Passage.Configuration.Views(passwordResetConfirm: confirmView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig, captured: captured)

            // Create a user
            let email = "user@example.com"
            let password = "OldPassword123!"
            let newPassword = "NewPassword456!"
            let passwordHash = try await app.password.async.hash(password)
            let identifier = Identifier.email(email)
            let credential = Credential.password(passwordHash)
            let store = app.passage.storage.services.store
            _ = try await store.users.create(identifier: identifier, with: credential)

            // Request password reset to get a code (via HTTP endpoint)
            try await app.testing().test(.POST, "/auth/password/reset/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            }, afterResponse: { res in
                #expect(res.status == .ok)
            })

            // Get the reset code from captured email
            let resetCode = try #require(captured.emails.first?.passwordResetCode)

            // Submit password reset confirm form
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)&code=\(resetCode)&newPassword=\(newPassword)"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should redirect to custom success location
                let location = res.headers.first(name: .location)
                #expect(location == "/login")
            })
        }
    }

    @Test
    func `Password reset confirm form submission with custom redirect on failure`() async throws {
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: nil,
            onFailure: "/reset-error"
        )
        let confirmView = Passage.Configuration.Views.PasswordResetConfirmView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: redirect
        )
        let viewsConfig = Passage.Configuration.Views(passwordResetConfirm: confirmView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            // Create a user
            let email = "user@example.com"
            let password = "OldPassword123!"
            let passwordHash = try await app.password.async.hash(password)
            let identifier = Identifier.email(email)
            let credential = Credential.password(passwordHash)
            let store = app.passage.storage.services.store
            _ = try await store.users.create(identifier: identifier, with: credential)

            // Submit with invalid code
            try await app.testing().test(.POST, "/auth/password/reset/email/verify", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)&code=INVALID&newPassword=NewPassword456!"), afterResponse: { res in
                // Should redirect
                #expect(res.status == .seeOther || res.status == .found)

                // Should redirect to custom failure location
                let location = res.headers.first(name: .location)
                #expect(location == "/reset-error")
            })
        }
    }

    // MARK: - Configuration Integration Tests

    @Test
    func `Views configuration is properly integrated with Passage configuration`() async throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: theme,
            identifier: .email
        )
        let registerView = Passage.Configuration.Views.RegisterView(
            style: .minimalism,
            theme: theme,
            identifier: .email
        )
        let resetRequestView = Passage.Configuration.Views.PasswordResetRequestView(
            style: .minimalism,
            theme: theme
        )

        let viewsConfig = Passage.Configuration.Views(
            register: registerView,
            login: loginView,
            passwordResetRequest: resetRequestView
        )

        // Verify views are enabled when configured
        #expect(viewsConfig.enabled == true)

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            // Verify app configured successfully with views
            #expect(app.passage.storage.configuration.views.enabled == true)
            #expect(app.passage.storage.configuration.views.login != nil)
            #expect(app.passage.storage.configuration.views.register != nil)
            #expect(app.passage.storage.configuration.views.passwordResetRequest != nil)
        }
    }

    @Test
    func `Views configuration is properly disabled when no views configured`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        // Verify views are disabled when not configured
        #expect(viewsConfig.enabled == false)

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            // Verify app configured successfully without views
            #expect(app.passage.storage.configuration.views.enabled == false)
            #expect(app.passage.storage.configuration.views.login == nil)
            #expect(app.passage.storage.configuration.views.register == nil)
            #expect(app.passage.storage.configuration.views.passwordResetRequest == nil)
            #expect(app.passage.storage.configuration.views.passwordResetConfirm == nil)
        }
    }

    @Test
    func `Different view styles and themes can be configured`() async throws {
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let registerView = Passage.Configuration.Views.RegisterView(
            style: .neobrutalism,
            theme: Passage.Views.Theme(colors: .oceanLight),
            identifier: .phone
        )
        let resetRequestView = Passage.Configuration.Views.PasswordResetRequestView(
            style: .material,
            theme: Passage.Views.Theme(colors: .forestLight)
        )

        let viewsConfig = Passage.Configuration.Views(
            register: registerView,
            login: loginView,
            passwordResetRequest: resetRequestView
        )

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            // Verify different styles are properly configured
            #expect(app.passage.storage.configuration.views.login?.style == .minimalism)
            #expect(app.passage.storage.configuration.views.register?.style == .neobrutalism)
            #expect(app.passage.storage.configuration.views.passwordResetRequest?.style == .material)

            // Verify different identifiers are configured
            #expect(app.passage.storage.configuration.views.login?.identifier == .email)
            #expect(app.passage.storage.configuration.views.register?.identifier == .phone)
        }
    }

    @Test
    func `View redirect configuration is properly stored`() async throws {
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: "/dashboard",
            onFailure: "/error"
        )
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: redirect,
            identifier: .email
        )

        let viewsConfig = Passage.Configuration.Views(login: loginView)

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            // Verify redirect configuration is stored
            #expect(app.passage.storage.configuration.views.login?.redirect.onSuccess == "/dashboard")
            #expect(app.passage.storage.configuration.views.login?.redirect.onFailure == "/error")
        }
    }

    // MARK: - Magic Link Request View 404 Tests

    @Test
    func `Magic link request view returns 404 when not configured`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            try await app.testing().test(.GET, "/auth/magic-link/email", afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    // MARK: - Magic Link Request View Rendering Tests

    @Test
    func `Magic link request view renders magic-link-request-minimalism template`() async throws {
        let magicLinkRequestView = Passage.Configuration.Views.MagicLinkRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(magicLinkRequest: magicLinkRequestView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/magic-link/email", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "magic-link-request-minimalism")

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.MagicLinkRequestViewParams>
                #expect(ctx?.params.byEmail == true)
            })
        }
    }

    @Test
    func `Magic link request view renders magic-link-request-neobrutalism template`() async throws {
        let magicLinkRequestView = Passage.Configuration.Views.MagicLinkRequestView(
            style: .neobrutalism,
            theme: Passage.Views.Theme(colors: .oceanLight)
        )
        let viewsConfig = Passage.Configuration.Views(magicLinkRequest: magicLinkRequestView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/magic-link/email", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "magic-link-request-neobrutalism")

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.MagicLinkRequestViewParams>
                #expect(ctx?.params.byEmail == true)
            })
        }
    }

    @Test
    func `Magic link request view captures query parameters in context`() async throws {
        let magicLinkRequestView = Passage.Configuration.Views.MagicLinkRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(magicLinkRequest: magicLinkRequestView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/magic-link/email?error=Invalid+email", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "magic-link-request-minimalism")

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.MagicLinkRequestViewParams>
                #expect(ctx?.params.error == "Invalid email")
            })
        }
    }

    // MARK: - Magic Link Request Form Submission Tests

    @Test
    func `Magic link request form submission succeeds and redirects with success message`() async throws {
        let magicLinkRequestView = Passage.Configuration.Views.MagicLinkRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(magicLinkRequest: magicLinkRequestView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            let email = "user@example.com"

            try await app.testing().test(.POST, "/auth/magic-link/email", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)"), afterResponse: { res in
                #expect(res.status == .seeOther || res.status == .found)

                let location = res.headers.first(name: .location)
                #expect(location != nil)

                #expect(location?.contains("/auth/magic-link/email") == true)
                #expect(location?.contains("success=") == true)
                #expect(location?.contains("identifier=\(email)") == true)
            })
        }
    }

    @Test
    func `Magic link request form submission fails with invalid email format`() async throws {
        let magicLinkRequestView = Passage.Configuration.Views.MagicLinkRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(magicLinkRequest: magicLinkRequestView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            try await app.testing().test(.POST, "/auth/magic-link/email", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=invalid-email"), afterResponse: { res in
                #expect(res.status == .seeOther || res.status == .found)

                let location = res.headers.first(name: .location)
                #expect(location != nil)
                #expect(location?.contains("/auth/magic-link/email") == true)
                #expect(location?.contains("error=") == true)
            })
        }
    }

    @Test
    func `Magic link request form submission with custom redirect on success`() async throws {
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: "/check-email",
            onFailure: nil
        )
        let magicLinkRequestView = Passage.Configuration.Views.MagicLinkRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: redirect
        )
        let viewsConfig = Passage.Configuration.Views(magicLinkRequest: magicLinkRequestView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            let email = "user@example.com"

            try await app.testing().test(.POST, "/auth/magic-link/email", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=\(email)"), afterResponse: { res in
                #expect(res.status == .seeOther || res.status == .found)

                let location = res.headers.first(name: .location)
                #expect(location == "/check-email")
            })
        }
    }

    @Test
    func `Magic link request form submission with custom redirect on failure`() async throws {
        let redirect = Passage.Configuration.Views.Redirect(
            onSuccess: nil,
            onFailure: "/magic-link-error"
        )
        let magicLinkRequestView = Passage.Configuration.Views.MagicLinkRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: redirect
        )
        let viewsConfig = Passage.Configuration.Views(magicLinkRequest: magicLinkRequestView)

        try await withApp { app in
            try await configure(app, viewsConfig: viewsConfig)

            try await app.testing().test(.POST, "/auth/magic-link/email", headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "text/html"
            ], body: .init(string: "email=invalid-email"), afterResponse: { res in
                #expect(res.status == .seeOther || res.status == .found)

                let location = res.headers.first(name: .location)
                #expect(location == "/magic-link-error")
            })
        }
    }

    // MARK: - Magic Link Verify View 404 Tests

    @Test
    func `Magic link verify view returns API response when views not configured`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            // When views are not configured, the API endpoint is still available
            // and returns 401 for invalid token instead of 404
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=test", afterResponse: { res in
                #expect(res.status == .unauthorized)
            })
        }
    }

    // MARK: - Magic Link Verify View Rendering Tests

    @Test
    func `Magic link verify view renders magic-link-verify-minimalism template`() async throws {
        let magicLinkVerifyView = Passage.Configuration.Views.MagicLinkVerifyView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: .init(onSuccess: "/dashboard")
        )
        let viewsConfig = Passage.Configuration.Views(magicLinkVerify: magicLinkVerifyView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/magic-link/email/verify", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "magic-link-verify-minimalism")

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.MagicLinkVerifyViewParams>
                #expect(ctx?.params.error?.starts(with: "Validation error:") == true)
            })
        }
    }

    @Test
    func `Magic link verify view renders magic-link-verify-neobrutalism template`() async throws {
        let magicLinkVerifyView = Passage.Configuration.Views.MagicLinkVerifyView(
            style: .neobrutalism,
            theme: Passage.Views.Theme(colors: .oceanLight),
            redirect: .init(onSuccess: "/dashboard")
        )
        let viewsConfig = Passage.Configuration.Views(magicLinkVerify: magicLinkVerifyView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/magic-link/email/verify", afterResponse: { res in
                #expect(res.status == .ok)
                #expect(renderer.templatePath == "magic-link-verify-neobrutalism")

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.MagicLinkVerifyViewParams>
                #expect(ctx?.params.error?.starts(with: "Validation error:") == true)
            })
        }
    }

    // MARK: - Magic Link Verify Success/Error Redirection Tests

    @Test
    func `Magic link verify renders success view on valid token`() async throws {
        let captured = CapturedMessages()
        let magicLinkVerifyView = Passage.Configuration.Views.MagicLinkVerifyView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: .init(onSuccess: "/dashboard")
        )
        let viewsConfig = Passage.Configuration.Views(magicLinkVerify: magicLinkVerifyView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer, captured: captured)

            let email = "verify@example.com"

            // Request magic link
            try await app.testing().test(.POST, "/auth/magic-link/email", beforeRequest: { req in
                try req.content.encode(["email": email])
            })

            try await app.queues.queue.worker.run()

            let magicLinkURL = try #require(captured.emails.first?.magicLinkURL)
            let components = URLComponents(url: magicLinkURL, resolvingAgainstBaseURL: false)
            let token = try #require(components?.queryItems?.first(where: { $0.name == "token" })?.value)

            // Encode token for URL
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "+/=")
            let encodedToken = try #require(token.addingPercentEncoding(withAllowedCharacters: allowed))

            // Verify magic link - should render success view directly
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=\(encodedToken)") { res in
                #expect(res.status == .ok)

                // Verify the template was rendered
                #expect(renderer.templatePath == "magic-link-verify-minimalism")

                // Verify success message and redirect URL are in context
                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.MagicLinkVerifyViewParams>
                #expect(ctx?.params.success != nil)
                #expect(ctx?.params.redirectUrl == "/dashboard")
            }
        }
    }

    @Test
    func `Magic link verify renders error view on invalid token`() async throws {
        let magicLinkVerifyView = Passage.Configuration.Views.MagicLinkVerifyView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            redirect: .init(onSuccess: "/dashboard")
        )
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(
            login: loginView,
            magicLinkVerify: magicLinkVerifyView
        )

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            // Verify with invalid token - should render error view directly
            try await app.testing().test(.GET, "/auth/magic-link/email/verify?token=invalid-token") { res in
                #expect(res.status == .ok)

                // Verify the template was rendered
                #expect(renderer.templatePath == "magic-link-verify-minimalism")

                // Verify error message and login link are in context
                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.MagicLinkVerifyViewParams>
                #expect(ctx?.params.error != nil)
                #expect(ctx?.params.loginLink == "/login")
            }
        }
    }

    // MARK: - Login View Magic Link Button Tests

    @Test
    func `Login view includes magic link button when magic link is configured`() async throws {
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let magicLinkRequestView = Passage.Configuration.Views.MagicLinkRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let viewsConfig = Passage.Configuration.Views(
            login: loginView,
            magicLinkRequest: magicLinkRequestView
        )

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/login", afterResponse: { res in
                #expect(res.status == .ok)

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.LoginViewParams>
                #expect(ctx?.params.byEmailMagicLink == true)
                #expect(ctx?.params.magicLinkRequestLink != nil)
                // Path doesn't include group prefix, just the route path
                #expect(ctx?.params.magicLinkRequestLink?.contains("magic-link/email") == true)
            })
        }
    }

    @Test
    func `Login view does not include magic link button when magic link is not configured`() async throws {
        let loginView = Passage.Configuration.Views.LoginView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight),
            identifier: .email
        )
        let viewsConfig = Passage.Configuration.Views(login: loginView)

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configure(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            try await app.testing().test(.GET, "/auth/login", afterResponse: { res in
                #expect(res.status == .ok)

                let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.LoginViewParams>
                #expect(ctx?.params.byEmailMagicLink == false)
                #expect(ctx?.params.magicLinkRequestLink == nil)
            })
        }
    }

    // MARK: - Magic Link Configuration Integration Tests

    @Test
    func `Magic link views configuration is properly integrated`() async throws {
        let magicLinkRequestView = Passage.Configuration.Views.MagicLinkRequestView(
            style: .minimalism,
            theme: Passage.Views.Theme(colors: .defaultLight)
        )
        let magicLinkVerifyView = Passage.Configuration.Views.MagicLinkVerifyView(
            style: .neobrutalism,
            theme: Passage.Views.Theme(colors: .oceanLight),
            redirect: .init(onSuccess: "/dashboard")
        )

        let viewsConfig = Passage.Configuration.Views(
            magicLinkRequest: magicLinkRequestView,
            magicLinkVerify: magicLinkVerifyView
        )

        #expect(viewsConfig.enabled == true)
        #expect(viewsConfig.magicLinkRequest != nil)
        #expect(viewsConfig.magicLinkVerify != nil)

        try await withApp(configure: { app in try await configure(app, viewsConfig: viewsConfig) }) { app in
            #expect(app.passage.storage.configuration.views.enabled == true)
            #expect(app.passage.storage.configuration.views.magicLinkRequest?.style == .minimalism)
            #expect(app.passage.storage.configuration.views.magicLinkVerify?.style == .neobrutalism)
            #expect(app.passage.storage.configuration.views.magicLinkVerify?.redirect.onSuccess == "/dashboard")
        }
    }

    // MARK: - OAuth Link Account Select View Tests (lines 368-391)

    /// Configures test app with Link Accounting and sessions enabled
    @Sendable private func configureWithOAuthLinking(
        _ app: Application,
        viewsConfig: Passage.Configuration.Views,
        captureRenderer: CapturingViewRenderer? = nil
    ) async throws {
        // Enable sessions middleware (required for linking state)
        app.middleware.use(app.sessions.middleware)

        // Use capturing renderer if provided
        if let renderer = captureRenderer {
            app.views.use { req in
                renderer
            }
        }

        // Add HMAC key for JWT
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        // Configure Passage with test services
        let store = Passage.OnlyForTest.InMemoryStore()
        let emailDelivery = Passage.OnlyForTest.MockEmailDelivery()
        let phoneDelivery = Passage.OnlyForTest.MockPhoneDelivery()

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
            sessions: .init(enabled: true),
            jwt: .init(jwks: .init(json: emptyJwks)),
            verification: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: false
            ),
            restoration: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: false
            ),
            federatedLogin: .init(
                providers: [],
                accountLinking: .init(
                    resolution: .manual(matchBy: [.email]),
                    stateExpiration: 600
                ),
                redirectLocation: "/dashboard"
            ),
            views: viewsConfig
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration
        )

        // Register test route to initiate linking session
        app.post("test", "initiate-linking") { req async throws -> Response in
            struct InitiateRequest: Content {
                let provider: String
                let userId: String
                let verifiedEmails: [String]
            }

            let body = try req.content.decode(InitiateRequest.self)

            let identity = FederatedIdentity(
                identifier: .federated(.named(body.provider), userId: body.userId),
                provider: .named(body.provider),
                verifiedEmails: body.verifiedEmails,
                verifiedPhoneNumbers: [],
                displayName: nil,
                profilePictureURL: nil
            )

            _ = try await req.linking.manual.initiate(
                for: identity,
                withAllowedIdentifiers: [.email]
            )

            return Response(status: .ok)
        }

        // Register test route to advance linking (select user)
        app.post("test", "advance-linking") { req async throws -> Response in
            struct AdvanceRequest: Content {
                let userId: String
            }

            let body = try req.content.decode(AdvanceRequest.self)
            try await req.linking.manual.advance(withSelectedUserId: body.userId)

            return Response(status: .ok)
        }
    }

    /// Creates a test user with the given identifier
    @Sendable private func createTestUserForOAuth(
        app: Application,
        email: String,
        password: String? = nil,
        isEmailVerified: Bool = false
    ) async throws -> any User {
        let store = app.passage.storage.services.store

        let identifier = Identifier.email(email)

        var credential: Credential? = nil
        if let password = password {
            let passwordHash = try await app.password.async.hash(password)
            credential = .password(passwordHash)
        }

        let user = try await store.users.create(identifier: identifier, with: credential)

        if isEmailVerified {
            try await store.users.markEmailVerified(for: user)
        }

        return user
    }

    /// Extracts session cookie from response headers
    private func extractSessionCookie(from response: TestingHTTPResponse) -> String? {
        if let cookieHeader = response.headers[.setCookie].first(where: { $0.contains("vapor-session") }) {
            let parts = cookieHeader.split(separator: ";")
            if let cookiePart = parts.first {
                return String(cookiePart)
            }
        }
        return nil
    }

    @Test
    func `Link Account select view returns 404 when not configured`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        try await withApp(configure: { app in
            try await configureWithOAuthLinking(app, viewsConfig: viewsConfig)
        }) { app in
            try await app.testing().test(.GET, "/auth/connect/link/select", afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test
    func `Link Account select view returns error when no linking session exists`() async throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let viewsConfig = Passage.Configuration.Views(
            linkAccountSelect: .init(style: .minimalism, theme: theme),
            linkAccountVerify: .init(style: .minimalism, theme: theme)
        )

        try await withApp { app in
            try await configureWithOAuthLinking(app, viewsConfig: viewsConfig)

            try await app.testing().test(.GET, "/auth/connect/link/select", afterResponse: { res in
                // Should return bad request because no linking session exists
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test
    func `Link Account select view renders with valid session and candidates`() async throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let viewsConfig = Passage.Configuration.Views(
            linkAccountSelect: .init(style: .minimalism, theme: theme),
            linkAccountVerify: .init(style: .minimalism, theme: theme)
        )

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configureWithOAuthLinking(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            // Create candidate user
            _ = try await createTestUserForOAuth(
                app: app,
                email: "candidate@example.com",
                password: "password123",
                isEmailVerified: true
            )

            var sessionCookie: String?

            // Initiate linking session
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    struct InitiateRequest: Content {
                        let provider: String
                        let userId: String
                        let verifiedEmails: [String]
                    }
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "some-123",
                        verifiedEmails: ["candidate@example.com"]
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // GET the link select view with session
            try await app.testing().test(
                .GET, "/auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                },
                afterResponse: { res in
                    #expect(res.status == .ok)

                    // Verify correct template was requested
                    #expect(renderer.templatePath == "link-account-select-minimalism")

                    // Verify context was passed with candidates
                    let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.LinkAccountSelectViewParams>
                    #expect(ctx?.params.provider == "google")
                    #expect(ctx?.params.candidates.count == 1)
                    #expect(ctx?.params.candidates.first?.maskedEmail != nil)
                    #expect(ctx?.params.error == nil)
                }
            )
        }
    }

    @Test
    func `Link Account select view renders with multiple candidates`() async throws {
        let theme = Passage.Views.Theme(colors: .oceanLight)
        let viewsConfig = Passage.Configuration.Views(
            linkAccountSelect: .init(style: .neobrutalism, theme: theme),
            linkAccountVerify: .init(style: .neobrutalism, theme: theme)
        )

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configureWithOAuthLinking(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            // Create multiple candidate users
            _ = try await createTestUserForOAuth(
                app: app,
                email: "user1@example.com",
                password: "password123",
                isEmailVerified: true
            )
            _ = try await createTestUserForOAuth(
                app: app,
                email: "user2@example.com",
                password: "password456",
                isEmailVerified: true
            )

            var sessionCookie: String?

            // Initiate linking session with multiple verified emails
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    struct InitiateRequest: Content {
                        let provider: String
                        let userId: String
                        let verifiedEmails: [String]
                    }
                    try req.content.encode(InitiateRequest(
                        provider: "github",
                        userId: "some-456",
                        verifiedEmails: ["user1@example.com", "user2@example.com"]
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // GET the link select view
            try await app.testing().test(
                .GET, "/auth/connect/link/select",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    #expect(renderer.templatePath == "link-account-select-neobrutalism")

                    let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.LinkAccountSelectViewParams>
                    #expect(ctx?.params.provider == "github")
                    #expect(ctx?.params.candidates.count == 2)
                }
            )
        }
    }

    // MARK: - OAuth Link Account Verify View Tests (lines 422-451)

    @Test
    func `Link Account verify view returns 404 when not configured`() async throws {
        let viewsConfig = Passage.Configuration.Views()

        try await withApp(configure: { app in
            try await configureWithOAuthLinking(app, viewsConfig: viewsConfig)
        }) { app in
            try await app.testing().test(.GET, "/auth/connect/link/verify", afterResponse: { res in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test
    func `Link Account verify view returns error when no linking session exists`() async throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let viewsConfig = Passage.Configuration.Views(
            linkAccountSelect: .init(style: .minimalism, theme: theme),
            linkAccountVerify: .init(style: .minimalism, theme: theme)
        )

        try await withApp { app in
            try await configureWithOAuthLinking(app, viewsConfig: viewsConfig)

            try await app.testing().test(.GET, "/auth/connect/link/verify", afterResponse: { res in
                // Should return bad request because no linking session exists
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test
    func `Link Account verify view returns bad request when no user selected`() async throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let viewsConfig = Passage.Configuration.Views(
            linkAccountSelect: .init(style: .minimalism, theme: theme),
            linkAccountVerify: .init(style: .minimalism, theme: theme)
        )

        try await withApp { app in
            try await configureWithOAuthLinking(app, viewsConfig: viewsConfig)

            // Create candidate user
            _ = try await createTestUserForOAuth(
                app: app,
                email: "candidate@example.com",
                password: "password123",
                isEmailVerified: true
            )

            var sessionCookie: String?

            // Initiate linking session (but don't advance/select user)
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    struct InitiateRequest: Content {
                        let provider: String
                        let userId: String
                        let verifiedEmails: [String]
                    }
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "some-789",
                        verifiedEmails: ["candidate@example.com"]
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // Try to access verify view without selecting a user
            try await app.testing().test(
                .GET, "/auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                },
                afterResponse: { res in
                    // Should return bad request because no user has been selected
                    #expect(res.status == .badRequest)
                }
            )
        }
    }

    @Test
    func `Link Account verify view renders with valid session and selected user with password`() async throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let viewsConfig = Passage.Configuration.Views(
            linkAccountSelect: .init(style: .minimalism, theme: theme),
            linkAccountVerify: .init(style: .minimalism, theme: theme)
        )

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configureWithOAuthLinking(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            // Create candidate user with password
            let user = try await createTestUserForOAuth(
                app: app,
                email: "password-user@example.com",
                password: "securepassword",
                isEmailVerified: true
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Initiate linking session
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    struct InitiateRequest: Content {
                        let provider: String
                        let userId: String
                        let verifiedEmails: [String]
                    }
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "some-pw-test",
                        verifiedEmails: ["password-user@example.com"]
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // Advance linking (select user)
            try await app.testing().test(
                .POST, "test/advance-linking",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    struct AdvanceRequest: Content {
                        let userId: String
                    }
                    try req.content.encode(AdvanceRequest(userId: userId))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    // Update session cookie if new one was set
                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            // GET the link verify view
            try await app.testing().test(
                .GET, "/auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                },
                afterResponse: { res in
                    #expect(res.status == .ok)

                    // Verify correct template was requested
                    #expect(renderer.templatePath == "link-account-verify-minimalism")

                    // Verify context was passed correctly
                    let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.LinkAccountVerifyViewParams>
                    #expect(ctx?.params.maskedEmail != nil)
                    #expect(ctx?.params.hasPassword == true)
                    #expect(ctx?.params.canUseEmailCode == false)  // Has password, so can't use email code
                    #expect(ctx?.params.error == nil)
                }
            )
        }
    }

    @Test
    func `Link Account verify view renders with user who can use email code`() async throws {
        let theme = Passage.Views.Theme(colors: .forestLight)
        let viewsConfig = Passage.Configuration.Views(
            linkAccountSelect: .init(style: .material, theme: theme),
            linkAccountVerify: .init(style: .material, theme: theme)
        )

        try await withApp { app in
            let renderer = CapturingViewRenderer(eventLoop: app.eventLoopGroup.any())
            try await configureWithOAuthLinking(app, viewsConfig: viewsConfig, captureRenderer: renderer)

            // Create candidate user WITHOUT password but with verified email
            let user = try await createTestUserForOAuth(
                app: app,
                email: "no-password@example.com",
                password: nil,  // No password
                isEmailVerified: true  // But email is verified
            )
            let userId = user.id!.description

            var sessionCookie: String?

            // Initiate linking session
            try await app.testing().test(
                .POST, "test/initiate-linking",
                beforeRequest: { req in
                    struct InitiateRequest: Content {
                        let provider: String
                        let userId: String
                        let verifiedEmails: [String]
                    }
                    try req.content.encode(InitiateRequest(
                        provider: "google",
                        userId: "some-email-code",
                        verifiedEmails: ["no-password@example.com"]
                    ))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    sessionCookie = extractSessionCookie(from: res)
                }
            )

            #expect(sessionCookie != nil)

            // Advance linking (select user)
            try await app.testing().test(
                .POST, "test/advance-linking",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                    struct AdvanceRequest: Content {
                        let userId: String
                    }
                    try req.content.encode(AdvanceRequest(userId: userId))
                },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    if let newCookie = extractSessionCookie(from: res) {
                        sessionCookie = newCookie
                    }
                }
            )

            // GET the link verify view
            try await app.testing().test(
                .GET, "/auth/connect/link/verify",
                beforeRequest: { req in
                    if let cookie = sessionCookie {
                        req.headers.add(name: .cookie, value: cookie)
                    }
                },
                afterResponse: { res in
                    #expect(res.status == .ok)

                    // Verify correct template was requested
                    #expect(renderer.templatePath == "link-account-verify-material")

                    // Verify context shows canUseEmailCode is true
                    let ctx = renderer.capturedContext as? Passage.Views.Context<Passage.Views.LinkAccountVerifyViewParams>
                    #expect(ctx?.params.maskedEmail != nil)
                    #expect(ctx?.params.hasPassword == false)
                    #expect(ctx?.params.canUseEmailCode == true)  // No password + verified email = can use code
                    #expect(ctx?.params.error == nil)
                }
            )
        }
    }

    @Test
    func `Link Account select and verify views configuration integration`() async throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let linkSelectView = Passage.Configuration.Views.LinkAccountSelectView(
            style: .minimalism,
            theme: theme
        )
        let linkVerifyView = Passage.Configuration.Views.LinkAccountVerifyView(
            style: .neobrutalism,
            theme: Passage.Views.Theme(colors: .oceanLight)
        )

        let viewsConfig = Passage.Configuration.Views(
            linkAccountSelect: linkSelectView,
            linkAccountVerify: linkVerifyView
        )

        #expect(viewsConfig.enabled == true)
        #expect(viewsConfig.linkAccountSelect != nil)
        #expect(viewsConfig.linkAccountVerify != nil)

        try await withApp(configure: { app in
            try await configureWithOAuthLinking(app, viewsConfig: viewsConfig)
        }) { app in
            #expect(app.passage.storage.configuration.views.enabled == true)
            #expect(app.passage.storage.configuration.views.linkAccountSelect?.style == .minimalism)
            #expect(app.passage.storage.configuration.views.linkAccountVerify?.style == .neobrutalism)
        }
    }
}

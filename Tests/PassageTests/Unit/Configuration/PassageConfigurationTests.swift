import Foundation
import RoutingKit
@testable import Passage
import Testing

@Suite("Passage Configuration Tests")
struct PassageConfigurationTests {

    // MARK: - Configuration Initialization Tests

    @Test("Configuration with minimal required parameters")
    func configurationMinimal() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )

        #expect(config.origin.absoluteString == "https://example.com")
        #expect(config.jwt.jwks.json == "{}")
        #expect(config.routes.group[0].description == "auth")
        #expect(config.tokens.issuer == nil)
        #expect(config.verification.useQueues == false)
        #expect(config.restoration.useQueues == false)
        #expect(config.federatedLogin.providers.isEmpty)
        #expect(config.views.enabled == false)
    }

    @Test("Configuration with custom routes")
    func configurationWithCustomRoutes() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            routes: .init(
                group: "api", "v1",
                register: .init(path: "signup")
            ),
            jwt: .init(jwks: .init(json: "{}"))
        )

        #expect(config.routes.group.count == 2)
        #expect(config.routes.group[0].description == "api")
        #expect(config.routes.register.path[0].description == "signup")
    }

    @Test("Configuration with custom tokens")
    func configurationWithCustomTokens() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            tokens: .init(
                issuer: "https://auth.example.com",
                accessToken: .init(timeToLive: 600)
            ),
            jwt: .init(jwks: .init(json: "{}"))
        )

        #expect(config.tokens.issuer == "https://auth.example.com")
        #expect(config.tokens.accessToken.timeToLive == 600)
    }

    @Test("Configuration with custom verification")
    func configurationWithCustomVerification() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}")),
            verification: .init(
                email: .init(codeLength: 8),
                phone: .init(codeLength: 4),
                useQueues: true
            )
        )

        #expect(config.verification.email.codeLength == 8)
        #expect(config.verification.phone.codeLength == 4)
        #expect(config.verification.useQueues == true)
    }

    @Test("Configuration with custom restoration")
    func configurationWithCustomRestoration() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}")),
            restoration: .init(
                preferredDelivery: .phone,
                email: .init(codeLength: 8),
                useQueues: true
            )
        )

        #expect(config.restoration.preferredDelivery == .phone)
        #expect(config.restoration.email.codeLength == 8)
        #expect(config.restoration.useQueues == true)
    }

    @Test("Configuration with OAuth providers")
    func configurationWithOAuth() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}")),
            federatedLogin: .init(
                routes: .init(group: "social"),
                providers: [
                    .init(provider: .google()),
                    .init(provider: .github()),
                ]
            )
        )

        #expect(config.federatedLogin.providers.count == 2)
        #expect(config.federatedLogin.routes.group[0].description == "social")
    }

    @Test("Configuration with views enabled")
    func configurationWithViews() throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}")),
            views: .init(
                login: .init(style: .minimalism, theme: theme, identifier: .email)
            )
        )

        #expect(config.views.enabled == true)
        #expect(config.views.login != nil)
    }

    @Test("Configuration with all custom settings")
    func configurationFull() throws {
        let theme = Passage.Views.Theme(colors: .defaultLight)
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            routes: .init(
                group: "api",
                register: .init(path: "signup"),
                login: .init(path: "signin")
            ),
            tokens: .init(
                issuer: "https://auth.example.com",
                accessToken: .init(timeToLive: 900)
            ),
            jwt: .init(jwks: .init(json: "{}")),
            verification: .init(
                email: .init(codeLength: 8),
                useQueues: true
            ),
            restoration: .init(
                preferredDelivery: .email,
                useQueues: true
            ),
            federatedLogin: .init(
                routes: .init(group: "oauth"),
                providers: [.init(provider: .google())]
            ),
            views: .init(
                register: .init(style: .material, theme: theme, identifier: .email),
                login: .init(style: .material, theme: theme, identifier: .email)
            )
        )

        #expect(config.origin.absoluteString == "https://example.com")
        #expect(config.routes.group[0].description == "api")
        #expect(config.tokens.issuer == "https://auth.example.com")
        #expect(config.verification.useQueues == true)
        #expect(config.restoration.useQueues == true)
        #expect(config.federatedLogin.providers.count == 1)
        #expect(config.views.enabled == true)
    }

    @Test("Configuration default JWT from environment")
    func configurationDefaultJWT() throws {
        // Create temporary JWKS file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test-jwks-\(UUID().uuidString).json")

        let jwksJSON = """
        {"keys":[{"kty":"RSA","kid":"test"}]}
        """

        try jwksJSON.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Set environment variable
        setenv("JWKS_FILE_PATH", tempFile.path, 1)
        defer { unsetenv("JWKS_FILE_PATH") }

        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!
        )

        #expect(config.jwt.jwks.json.contains("test"))
    }

    @Test("Configuration fails with missing JWKS environment")
    func configurationMissingJWKS() {
        // Ensure JWKS and JWKS_FILE_PATH are not set
        unsetenv("JWKS")
        unsetenv("JWKS_FILE_PATH")

        #expect(throws: PassageError.self) {
            try Passage.Configuration(
                origin: URL(string: "https://example.com")!
            )
        }
    }

    @Test("Configuration Sendable conformance")
    func configurationSendableConformance() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )

        let _: any Sendable = config
    }

    // MARK: - URL Construction Tests

    @Test("Configuration constructs correct URLs")
    func configurationURLConstruction() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )

        // Test email verification URL
        #expect(config.emailVerificationURL.absoluteString == "https://example.com/auth/email/verify")

        // Test phone verification URL
        #expect(config.phoneVerificationURL.absoluteString == "https://example.com/auth/phone/verify")

        // Test email password reset URL
        #expect(config.emailPasswordResetURL.absoluteString == "https://example.com/auth/password/reset/email/verify")

        // Test phone password reset URL
        #expect(config.phonePasswordResetURL.absoluteString == "https://example.com/auth/password/reset/phone/verify")
    }

    @Test("Configuration constructs email reset link with query parameters")
    func configurationEmailResetLink() throws {
        let config = try Passage.Configuration(
            origin: URL(string: "https://example.com")!,
            jwt: .init(jwks: .init(json: "{}"))
        )

        let url = config.emailPasswordResetLinkURL(code: "123456", email: "test@example.com")

        #expect(url.absoluteString.contains("code=123456"))
        #expect(url.absoluteString.contains("email=test@example.com"))
        #expect(url.absoluteString.hasPrefix("https://example.com/auth/password/reset/email/verify"))
    }
}

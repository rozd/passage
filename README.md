# Passage
[![Release](https://img.shields.io/github/v/release/vapor-community/passage)](https://github.com/vapor-community/passage/releases)
[![Swift 6.3](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://swift.org)
[![License](https://img.shields.io/github/license/vapor-community/passage)](LICENSE)
[![codecov](https://codecov.io/gh/vapor-community/passage/branch/main/graph/badge.svg)](https://codecov.io/gh/vapor-community/passage)

A comprehensive identity management and authentication framework for Vapor applications built with Swift. Passage provides secure authentication with minimal configuration while remaining highly extensible through protocol-based architecture. **Not yet production-ready.**

## Status: Developer Preview

## Features

- 🔐 **User Registration & Login** - Complete authentication flow with secure password hashing
- 📧 **Email Authentication** - Email-based identifier with verification codes
- 📱 **Phone Authentication** - Phone number identifier with SMS verification (requires custom implementation of `PhoneDelivery` service)
- 👤 **Username & Password** - Traditional username/password authentication
- ✨ **Passwordless Magic Links** - Email-based passwordless authentication with one-click login
- 🎫 **JWT Access Tokens** - Stateless authentication with JWKS support
- 🔄 **Refresh Token Rotation** - Secure token refresh with family-based revocation
- 🔓 **Password Reset Flow** - Email and phone-based password recovery
- 🌐 **OAuth Integration** - Federated login (Google, GitHub, custom providers)
- 🔑 **Passkeys (WebAuthn)** - Phishing-resistant public-key credentials with three HTTP flows (public signup, authenticated "add passkey", discoverable sign-in), one-shot challenge storage, sign-count tracking, and opt-in Leaf templates for signup + sign-in — pluggable backend via `PasskeyService`
- 🔗 **Account Linking** - Link multiple identifiers to a single user account (automatic or manual)
- 📋 **Web Forms** - Built-in Leaf templates for registration, login, and password reset
- ⚡ **Async Queue Support** - Optional background job processing via Vapor Queues
- 🔧 **Protocol-Based Services** - Pluggable storage, email, phone, and OAuth providers
- 🎨 **Fully Customizable** - Configure routes, tokens, templates, and behavior

## Getting Started

### Installation

Add Passage to your `Package.swift`:

```swift
dependencies: [
    // 🛂 Authentication and user management for Vapor.
    .package(url: "https://github.com/vapor-community/passage", branch: "main"),
]
```

Then add `"Passage"` to your target dependencies:

```swift                
.product(name: "Passage", package: "passage"),
```

Add `PassageOnlyForTest` **only** if you want to use the in-memory store for testing:

```swift
.product(name: "PassageOnlyForTest", package: "passage"),
```

### Basic Setup
1. Set a custom working directory in your scheme and point it to your project folder.
2. Create a JWKS file `keypair.jwks` and place it in the root of your project.
3. Configure Passage in your `configure.swift`:

```swift
// enable Leaf templating to use Passage's built-in views
app.views.use(.leaf)

// enable sessions middleware
app.middleware.use(app.sessions.middleware)

// Configure Passage with in-memory store for testing
try await app.passage.configure(
    services: .init(
        store: Passage.OnlyForTest.InMemoryStore(),
        emailDelivery: nil,
        phoneDelivery: nil,
    ),
    configuration: .init(
        origin: URL(string: "http://localhost:8080")!,
        sessions: .init(enabled: true),
        jwt: .init(
            jwks: .file(path: "\(app.directory.workingDirectory)keypair.jwks")
        ),
        views: .init(
            register: .init(
                style: .minimalism,
                theme: .init(
                    colors: .mintDark
                ),
                identifier: .username
            ),
            login: .init(
                style: .minimalism,
                theme: .init(
                    colors: .mintDark
                ),
                identifier: .username
            )
        )
    )
)
```

### Example Usage
In your `routes.swift` file, protect routes using Passage's authenticators and guards:

```swift
app
    .grouped(PassageSessionAuthenticator())
    .grouped(PassageBearerAuthenticator())
    .grouped(PassageGuard())
    .get("protected") { req async throws -> String in
        let user = try req.passage.user
        return "Hello, \(String(describing: user.id))!"
}
```

This adds two view endpoints at `http://localhost:8080/auth/register` and `http://localhost:8080/auth/login` for user registration and login, as well as a protected route at `http://localhost:8080/protected` that requires authentication.

## Customization

Passage is designed for flexibility through:

- **Comprehensive Configuration** - Customize routes, token TTLs, JWT settings, verification flows, OAuth providers, and web forms
- **Protocol-Based Services** - Implement your own storage, email delivery, phone delivery, or OAuth providers
- **Extensible Forms** - Default form types can be replaced with custom implementations via contracts
- **Stylable Default Views** - Default Leaf views with different styles and themes

## Services to Implement

Passage exposes six service protocols for pluggable backends. Only `Store` is required; every other service is optional and unlocks a related feature when provided. Each section below links to [DEVELOPER_NOTES.md](./DEVELOPER_NOTES.md) for protocol signatures, sub-protocol breakdowns, invariants, and integration recipes.

<details>
<summary><h3>Store</h3> (Required) — persists users, tokens, verification codes, magic links, and passkey records.</summary>

#### Recommended implementation:
[passage-fluent](https://github.com/rozd/passage-fluent) — a Fluent-backed `DatabaseStore` with ready-made migrations for PostgreSQL, MySQL, and SQLite. For tests, use `PassageOnlyForTest.InMemoryStore`, which ships in this repo.

`Store` is a composite that exposes eight sub-stores — one per persistence concern (users, refresh tokens, verification codes, restoration codes, magic-link tokens, exchange tokens, and the two optional passkey stores). It is the one required service because every Passage feature ultimately reads or writes through it.

#### Implementation guide:
See [DEVELOPER_NOTES.md#store](./DEVELOPER_NOTES.md#store) for the full sub-store list, hashing invariants, and the refresh-token rotation chain.
</details>

<details>
<summary><h3>EmailDelivery</h3> (Optional) — sends verification codes, welcome emails, magic links, and password-reset emails.</summary>

#### Recommended implementation:
[passage-mailgun](https://github.com/rozd/passage-mailgun) — Mailgun-backed delivery configured with an API key, default domain, and sender identity. For SES, Postmark, Sendgrid, or other providers, conform to `Passage.EmailDelivery` against the provider SDK directly.

Supplying this service enables the email-side of every feature that sends mail: email verification, email-based password reset, magic-link passwordless login, and welcome emails on registration. Passage hands your implementation fully-constructed URLs, so there's no path construction on your side — template selection and HTML rendering are the only responsibilities.

#### Implementation guide:
See [DEVELOPER_NOTES.md#email-delivery](./DEVELOPER_NOTES.md#email-delivery) for the method-by-method surface and the Mailgun integration example.
</details>

<details>
<summary><h3>PhoneDelivery</h3> (Optional) — sends SMS verification codes and password-reset messages.</summary>

#### Recommended implementation:
no companion package ships yet — implement against Twilio, AWS SNS, Vonage, or your SMS gateway of choice.

Supplying this service enables phone-based verification and phone-based password reset. SMS messages carry raw codes rather than URLs, since users on mobile shouldn't need to click links. Message formatting — brand prefix, language, length — is entirely your implementation's choice.

#### Implementation guide:
See [DEVELOPER_NOTES.md#phone-delivery](./DEVELOPER_NOTES.md#phone-delivery) for the three methods and a Twilio-shaped example.
</details>

<details>
<summary><h3>FederatedLoginService</h3> (Optional) — registers OAuth provider routes and resolves federated identities on callback.</summary>

#### Recommended implementation:
[passage-imperial](https://github.com/rozd/passage-imperial) — integrates with the Imperial OAuth library to support GitHub, Google, and custom providers.

Unlike the other services, this one is a "bring a whole subsystem" contract: a single `register(...)` method that attaches provider routes onto Passage's router group and fires an `onSignIn` closure when a callback resolves. Passage uses that closure to reconcile against `UserStore` (linking, account-matching, creating) and to mint the exchange code the client swaps for an access token. See [`Sources/Passage/Features/FederatedLogin/README.md`](./Sources/Passage/Features/FederatedLogin/README.md) for the on-the-wire route shape.

#### Implementation guide:
See [DEVELOPER_NOTES.md#federated-login-service](./DEVELOPER_NOTES.md#federated-login-service) for the protocol signature and the Imperial wiring example.
</details>

<details>
<summary><h3>PasskeyService</h3> (Optional) — library-agnostic WebAuthn seam that drives all four passkey ceremony boundaries.</summary>

#### Recommended implementation:
[passage-webauthn](https://github.com/rozd/passage-webauthn) — wraps [swift-webauthn](https://github.com/swift-server/webauthn-swift). Relying-party identity and origins are configured on `WebAuthnManager.Configuration`, not on `Passage.Configuration.Passkey`.

`PasskeyService` is the single seam between Passage core and a concrete WebAuthn library — core has **zero** WebAuthn-library dependencies and talks only through this protocol. Providing a `PasskeyService` is the one gate that enables every passkey route; Passage additionally needs `Store.passkeyCredentials` and `Store.passkeyChallenges` sub-stores to be non-nil. `PassageFluent.DatabaseStore` will gain these alongside the upcoming passage-fluent model work; `PassageOnlyForTest.InMemoryStore` already includes them for tests.

Passage exposes three distinct passkey ceremony flows (public signup, authenticated "add passkey", discoverable sign-in), with one-shot challenge storage, sign-count tracking, and opt-in Leaf templates for signup and sign-in. See the [Passkey feature guide](./Sources/Passage/Features/Passkey/README.md) for the full route + DTO reference, trust models, and flow diagrams.

#### Implementation guide:
See [DEVELOPER_NOTES.md#passkey-service](./DEVELOPER_NOTES.md#passkey-service) for the four-method protocol surface, challenge-lookup invariants, and the `WebAuthnPasskeyService` integration example.
</details>

<details>
<summary><h3>RandomGenerator</h3> (Optional) — produces secure random tokens, verification codes, and SHA-256 hashes.</summary>

#### Recommended implementation:
`DefaultRandomGenerator` ships with Passage and is used unless you override it. Override only if you need a different code format (e.g. numeric-only codes for IVR flows) or stricter cryptographic guarantees.

The default generator emits 32-byte base64 opaque tokens, hex-encoded SHA-256 hashes, and verification codes drawn from a readability-tuned alphabet (`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`) that eliminates the visual ambiguity of `0/O` and `1/I/L`. Most apps should leave this service alone.

#### Implementation guide:
See [DEVELOPER_NOTES.md#random-generator](./DEVELOPER_NOTES.md#random-generator) for the protocol surface and a numeric-only override example.
</details>

## Configuration

Configure Passage behavior through the `Passage.Configuration` struct:

```swift
try await app.passage.configure(
    services: services,
    configuration: .init(
        // Base origin URL for your API
        origin: URL(string: "https://api.example.com")!,

        // Customize route paths
        routes: .init(
            group: "auth",              // Base path (default: "auth")
            register: .init(path: "register"),
            login: .init(path: "login"),
            logout: .init(path: "logout"),
            refreshToken: .init(path: "refresh-token"),
            currentUser: .init(path: "me")
        ),

        // Configure token lifetimes
        tokens: .init(
            issuer: "https://api.example.com",
            accessToken: .init(
                timeToLive: 900          // 15 minutes
            ),
            refreshToken: .init(
                timeToLive: 2_592_000    // 30 days
            ),
        ),

        // JWT/JWKS configuration
        jwt: .init(
            jwks: try .fileFromEnvironment(),  // Load from JWKS env var or file
        ),
        
        // Passwordless authentication (magic links)
        passwordless: .init(
            emailMagicLink: .email(
                autoCreateUser: true,
                requireSameBrowser: true
            )
        ),

        // Email/Phone verification settings; providing an `EmailDelivery` or `PhoneDelivery` service enables verification
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
            useQueues: true  // Global queue setting
        ),

        // Password reset settings; as with verification, providing `EmailDelivery` or `PhoneDelivery` enables password reset
        restoration: .init(
            preferredDelivery: .email,
            email: .init(
                codeLength: 6,
                codeExpiration: 600,
                maxAttempts: 5
            )
            useQueues: true
        ),

        // Federated Login configuration
        federatedLogin: .init(
            providers: [
                .github(
                    credentials: .conventional
                ),
                .google(
                    credentials: .conventional,
                    scope: ["profile", "email"]
                )
            ],
            accountLinking: .init(
                resolution: .automatic(
                    matchBy: [.email, .phone],
                    // Links accounts automatically by matching identifiers;
                    // falls back to manual linking when multiple matches exist
                    onAmbiguity: .requestManualSelection
                )
            )
        ),

        // Web form views (Leaf templates)
        views: .init(
            register: .init(/* ... */),
            login: .init(/* ... */),
            passwordResetRequest: .init(/* ... */)
        )
    )
)
```

### Key Configuration Options

- **Routes**: Customize all endpoint paths (registration, login, logout, token refresh, user info, verification, password reset)
- **Tokens**: Set TTLs for access and refresh tokens
- **JWT/JWKS**: Configure issuer, audience, and load JWKS from environment or file
- **Verification**: Enable/disable email/phone verification, set code TTLs, enable async queue processing
- **Restoration**: Configure password reset flows for email/phone
- **Passwordless**: Configure magic link authentication with link expiration, auto-create users, and same-browser verification
- **OAuth**: Define providers and callback routes
- **Passkeys**: Tune `policy` (`timeout`, `attestation`, `userVerification`, `supportedAlgorithms`, `allowDiscoverableLogin`), `challengeTTL`, and the per-ceremony route paths. The feature activates as soon as a `PasskeyService` is provided in `services`.
- **Views**: Enable web forms with customizable Leaf templates

### JWKS Configuration

Load JWKS from environment variable or file:

```bash
# Option 1: Environment variable
export JWKS='{"keys":[...]}'

# Option 2: File path
export JWKS_FILE_PATH="/path/to/jwks.json"
```

```swift
jwt: .init(jwks: try .fileFromEnvironment())
```

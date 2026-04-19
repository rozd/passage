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
- 🔑 **Passkeys (WebAuthn)** - Phishing-resistant public-key credentials with signup, sign-in, and "add passkey" flows — pluggable backend via `PasskeyService`
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
<summary><h3>🗄️ Store</h3> (Required) — persists users, tokens, verification codes, magic links, and passkey records.</summary>

#### Recommended implementation:
[passage-fluent](https://github.com/rozd/passage-fluent) — a Fluent-backed `DatabaseStore` with ready-made migrations for PostgreSQL, MySQL, and SQLite. For tests, use `PassageOnlyForTest.InMemoryStore`, which ships in this repo.

`Store` is a composite that exposes eight sub-stores — one per persistence concern (users, refresh tokens, verification codes, restoration codes, magic-link tokens, exchange tokens, and the two optional passkey stores). It is the one required service because every Passage feature ultimately reads or writes through it.

#### Implementation guide:
See [DEVELOPER_NOTES.md#store](./DEVELOPER_NOTES.md#store) for the full sub-store list, hashing invariants, and the refresh-token rotation chain.
</details>

<details>
<summary><h3>📧 EmailDelivery</h3> (Optional) — sends verification codes, welcome emails, magic links, and password-reset emails.</summary>

#### Recommended implementation:
[passage-mailgun](https://github.com/rozd/passage-mailgun) — Mailgun-backed delivery configured with an API key, default domain, and sender identity. For SES, Postmark, Sendgrid, or other providers, conform to `Passage.EmailDelivery` against the provider SDK directly.

Supplying this service enables the email-side of every feature that sends mail: email verification, email-based password reset, magic-link passwordless login, and welcome emails on registration. Passage hands your implementation fully-constructed URLs, so there's no path construction on your side — template selection and HTML rendering are the only responsibilities.

#### Implementation guide:
See [DEVELOPER_NOTES.md#email-delivery](./DEVELOPER_NOTES.md#email-delivery) for the method-by-method surface and the Mailgun integration example.
</details>

<details>
<summary><h3>📱 PhoneDelivery</h3> (Optional) — sends SMS verification codes and password-reset messages.</summary>

#### Recommended implementation:
no companion package ships yet — implement against Twilio, AWS SNS, Vonage, or your SMS gateway of choice.

Supplying this service enables phone-based verification and phone-based password reset. SMS messages carry raw codes rather than URLs, since users on mobile shouldn't need to click links. Message formatting — brand prefix, language, length — is entirely your implementation's choice.

#### Implementation guide:
See [DEVELOPER_NOTES.md#phone-delivery](./DEVELOPER_NOTES.md#phone-delivery) for the three methods and a Twilio-shaped example.
</details>

<details>
<summary><h3>🌐 FederatedLoginService</h3> (Optional) — registers OAuth provider routes and resolves federated identities on callback.</summary>

#### Recommended implementation:
[passage-imperial](https://github.com/rozd/passage-imperial) — integrates with the Imperial OAuth library to support GitHub, Google, and custom providers.

Unlike the other services, this one is a "bring a whole subsystem" contract: a single `register(...)` method that attaches provider routes onto Passage's router group and fires an `onSignIn` closure when a callback resolves. Passage uses that closure to reconcile against `UserStore` (linking, account-matching, creating) and to mint the exchange code the client swaps for an access token. See [`Sources/Passage/Features/FederatedLogin/README.md`](./Sources/Passage/Features/FederatedLogin/README.md) for the on-the-wire route shape.

#### Implementation guide:
See [DEVELOPER_NOTES.md#federated-login-service](./DEVELOPER_NOTES.md#federated-login-service) for the protocol signature and the Imperial wiring example.
</details>

<details>
<summary><h3>🔐 PasskeyService</h3> (Optional) — library-agnostic WebAuthn seam that drives all four passkey ceremony boundaries.</summary>

#### Recommended implementation:
[passage-webauthn](https://github.com/rozd/passage-webauthn) — wraps [swift-webauthn](https://github.com/swift-server/webauthn-swift). Relying-party identity and origins are configured on `WebAuthnManager.Configuration`, not on `Passage.Configuration.Passkey`.

`PasskeyService` is the single seam between Passage core and a concrete WebAuthn library — core has **zero** WebAuthn-library dependencies and talks only through this protocol. Providing a `PasskeyService` is the one gate that enables every passkey route; Passage additionally needs `Store.passkeyCredentials` and `Store.passkeyChallenges` sub-stores to be non-nil. `PassageFluent.DatabaseStore` will gain these alongside the upcoming passage-fluent model work; `PassageOnlyForTest.InMemoryStore` already includes them for tests.

Passage exposes three distinct passkey ceremony flows (public signup, authenticated "add passkey", discoverable sign-in), with one-shot challenge storage, sign-count tracking, and opt-in Leaf templates for signup and sign-in. See the [Passkey feature guide](./Sources/Passage/Features/Passkey/README.md) for the full route + DTO reference, trust models, and flow diagrams.

#### Implementation guide:
See [DEVELOPER_NOTES.md#passkey-service](./DEVELOPER_NOTES.md#passkey-service) for the four-method protocol surface, challenge-lookup invariants, and the `WebAuthnPasskeyService` integration example.
</details>

<details>
<summary><h3>🎲 RandomGenerator</h3> (Optional) — produces secure random tokens, verification codes, and SHA-256 hashes.</summary>

#### Recommended implementation:
`DefaultRandomGenerator` ships with Passage and is used unless you override it. Override only if you need a different code format (e.g. numeric-only codes for IVR flows) or stricter cryptographic guarantees.

The default generator emits 32-byte base64 opaque tokens, hex-encoded SHA-256 hashes, and verification codes drawn from a readability-tuned alphabet (`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`) that eliminates the visual ambiguity of `0/O` and `1/I/L`. Most apps should leave this service alone.

#### Implementation guide:
See [DEVELOPER_NOTES.md#random-generator](./DEVELOPER_NOTES.md#random-generator) for the protocol surface and a numeric-only override example.
</details>

## Feature Discovery

Each feature maps to a directory under [`Sources/Passage/Features/`](./Sources/Passage/Features/) and is activated independently by supplying the relevant service (where required) and configuration. Expand a section to see what to wire and where to find a working example.

<details>
<summary><h3>👤 Account</h3> — user registration, login, logout, and current-user retrieval.</summary>

#### Configuration
```swift
Passage.Configuration(
    // ... other config ...
    routes: .init(
        group: "auth",                                              // Base path for auth routes
        register: .init(path: "register"),                          // POST /auth/register
        login: .init(path: "login"),                                // POST /auth/login
        logout: .init(path: "logout"),                              // POST /auth/logout
        currentUser: .init(path: "me", shouldBypassGroup: true)     // GET /me
    )
)
```

#### Feature guide
See [`Sources/Passage/Features/Account/README.md`](./Sources/Passage/Features/Account/README.md) for the full route reference, error table, and flow diagrams.

#### Example
See [PassageExample in passage-example](https://github.com/rozd/passage-example#passageexample-1).
</details>

<details>
<summary><h3>✅ Verification</h3> — email and phone verification codes that confirm identifier ownership after registration.</summary>

#### Service setup
Requires `EmailDelivery` for email verification, `PhoneDelivery` for phone verification — supply either or both. See the [Services chapter](#services-to-implement) for integration options.

#### Configuration
```swift
Passage.Configuration(
    // ... other config ...
    verification: .init(
        email: .init(
            codeLength: 6,
            codeExpiration: 15 * 60,        // 15 minutes
            maxAttempts: 3
        ),
        phone: .init(
            codeLength: 6,
            codeExpiration: 5 * 60,         // 5 minutes (shorter for SMS)
            maxAttempts: 3
        ),
        useQueues: true                     // Dispatch send as Vapor Queue jobs
    )
)
```

Routes for each channel register only when the corresponding delivery service is provided. `useQueues: true` dispatches `SendEmailCodeJob` / `SendPhoneCodeJob` onto your Vapor Queues setup.

#### Feature guide
See [`Sources/Passage/Features/Verification/README.md`](./Sources/Passage/Features/Verification/README.md) for the verification flow, route list, and error reference.

#### Example
_No dedicated example yet — see [rozd/passage-example](https://github.com/rozd/passage-example) for the canonical walkthrough._
</details>

<details>
<summary><h3>🪄 Passwordless</h3> — magic-link authentication over email for password-free sign-in.</summary>

#### Service setup
Requires `EmailDelivery`. See the [Services chapter](#services-to-implement) for integration options.

#### Configuration
```swift
Passage.Configuration(
    // ... other config ...
    passwordless: .init(
        revokeExistingTokens: true,
        emailMagicLink: .email(
            useQueues: true,
            linkExpiration: 15 * 60,        // 15 minutes
            maxAttempts: 5,
            autoCreateUser: true,           // Create user on first successful link
            requireSameBrowser: false       // Gate verification to the requesting browser
        )
    )
)
```

#### Feature guide
See [`Sources/Passage/Features/Passwordless/README.md`](./Sources/Passage/Features/Passwordless/README.md) for the request/verify flow, same-browser enforcement, and token-security details.

#### Example
_No dedicated example yet — see [rozd/passage-example](https://github.com/rozd/passage-example) for the canonical walkthrough._
</details>

<details>
<summary><h3>🎟️ Tokens</h3> — JWT access tokens, opaque refresh tokens with rotation, and one-time exchange codes.</summary>

#### Configuration
```swift
Passage.Configuration(
    // ... other config ...
    tokens: .init(
        issuer: "https://api.example.com",                      // JWT `iss` claim
        accessToken: .init(timeToLive: 15 * 60),                // 15 minutes
        refreshToken: .init(timeToLive: 7 * 24 * 3600)          // 7 days
    ),
    jwt: .init(
        jwks: try .fileFromEnvironment()                        // JWKS env var or file
    ),
    routes: .init(
        refreshToken: .init(path: "refresh-token"),             // POST /auth/refresh-token
        exchangeCode: .init(path: "exchange")                   // POST /auth/exchange
    )
)
```

**JWKS loading** — `JWKS.fileFromEnvironment()` reads the JWKS payload from the `JWKS` environment variable or, failing that, from the path in `JWKS_FILE_PATH`:

```bash
export JWKS='{"keys":[...]}'
# or
export JWKS_FILE_PATH="/path/to/jwks.json"
```

Refresh tokens rotate on each refresh and revoke the entire token family on reuse detection — see the feature guide for the rotation chain.

#### Feature guide
See [`Sources/Passage/Features/Tokens/README.md`](./Sources/Passage/Features/Tokens/README.md) for claim definitions, rotation semantics, and exchange-code usage.

#### Example
_No dedicated example yet — see [rozd/passage-example](https://github.com/rozd/passage-example) for the canonical walkthrough._
</details>

<details>
<summary><h3>🔓 Restoration</h3> — password reset via email or SMS code, with automatic refresh-token revocation on success.</summary>

#### Service setup
Requires `EmailDelivery` for email reset, `PhoneDelivery` for phone reset — supply either or both. See the [Services chapter](#services-to-implement) for integration options.

#### Configuration
```swift
Passage.Configuration(
    // ... other config ...
    restoration: .init(
        preferredDelivery: .email,          // Fallback channel for username / federated logins
        email: .init(
            codeLength: 6,
            codeExpiration: 15 * 60,        // 15 minutes
            maxAttempts: 3
        ),
        phone: .init(
            codeLength: 6,
            codeExpiration: 5 * 60,         // 5 minutes
            maxAttempts: 3
        ),
        useQueues: true                     // Dispatch send as Vapor Queue jobs
    )
)
```

A successful reset hashes the new password with BCrypt and revokes **all** refresh tokens for the user, forcing re-authentication on every device.

#### Feature guide
See [`Sources/Passage/Features/Restoration/README.md`](./Sources/Passage/Features/Restoration/README.md) for the request/verify flow, token-revocation behavior, and error reference.

#### Example
_No dedicated example yet — see [rozd/passage-example](https://github.com/rozd/passage-example) for the canonical walkthrough._
</details>

<details>
<summary><h3>🌐 Federated Login</h3> — OAuth/OpenID Connect sign-in via Google, GitHub, Apple, or custom providers.</summary>

#### Service setup
Requires `FederatedLoginService`. Use [passage-imperial](https://github.com/rozd/passage-imperial) for a ready-made Imperial-based implementation:

```swift
import PassageImperial

let federatedLogin = ImperialFederatedLoginService(
    services: [
        .github          : GitHub.self,
        .named("google") : Google.self,
    ]
)
```

#### Configuration
```swift
Passage.Configuration(
    // ... other config ...
    federatedLogin: .init(
        routes: .init(group: "connect"),                        // Base path: /auth/connect
        providers: [
            .init(provider: .google),                           // /auth/connect/google
            .init(provider: .github)                            // /auth/connect/github
        ],
        redirectLocation: "/dashboard"                          // Post-login redirect target
    )
)
```

OAuth callbacks redirect to `redirectLocation` with an exchange `?code=…` that the client swaps for JWT tokens via `POST /auth/exchange`.

#### Feature guide
See [`Sources/Passage/Features/FederatedLogin/README.md`](./Sources/Passage/Features/FederatedLogin/README.md) for the OAuth flow, callback processing, and `FederatedIdentity` shape.

#### Example
See [PassageFederatedLoginExample in passage-example](https://github.com/rozd/passage-example#passagefederatedloginexample).
</details>

<details>
<summary><h3>🔑 Passkey</h3> — WebAuthn / FIDO2 passkeys with public signup, authenticated "add passkey", and discoverable sign-in flows.</summary>

#### Service setup
Requires `PasskeyService` plus the two passkey sub-stores on your `Store` (`passkeyCredentials`, `passkeyChallenges`). Use [passage-webauthn](https://github.com/rozd/passage-webauthn) for a ready-made `swift-webauthn`-backed implementation:

```swift
import PassageWebAuthn
import WebAuthn

let passkeyService = WebAuthnPasskeyService(
    configuration: WebAuthnManager.Configuration(
        relyingPartyID: "example.com",
        relyingPartyName: "My App",
        relyingPartyOrigin: "https://example.com"
    )
)
```

Relying-party identity and allowed origin are configured on the service's underlying `WebAuthnManager.Configuration`, not on `Configuration.Passkey`.

#### Configuration
```swift
Passage.Configuration(
    // ... other config ...
    passkey: .init(
        policy: .init(
            timeout: .seconds(60),
            attestation: .none,
            userVerification: .preferred,
            supportedAlgorithms: [.ES256, .RS256],
            allowDiscoverableLogin: true        // Required for the sign-in ceremony
        ),
        challengeTTL: 300                       // 5 minutes
    )
)
```

#### Feature guide
See [`Sources/Passage/Features/Passkey/README.md`](./Sources/Passage/Features/Passkey/README.md) for the three ceremony flows, route reference, DTOs, and flow diagrams.

#### Example
See [PassagePasskeyExample in passage-example](https://github.com/rozd/passage-example#passagepasskeyexample).
</details>

<details>
<summary><h3>🔗 Linking</h3> — links OAuth logins to existing user accounts by matching verified email or phone.</summary>

#### Service setup
Requires `FederatedLoginService` (linking is triggered from the OAuth callback). See the Federated Login section above for the service wiring.

#### Configuration
```swift
Passage.Configuration(
    // ... other config ...
    federatedLogin: .init(
        providers: [.google, .github],
        accountLinking: .init(
            resolution: .automatic(
                matchBy: [.email, .phone],                      // Match only verified identifiers
                onAmbiguity: .requestManualSelection            // Fall back to manual on multiple matches
            ),
            stateExpiration: 600                                // Manual linking flow TTL (seconds)
        )
    )
)
```

Only **verified** emails and phones are considered for automatic linking — this prevents account takeover through unverified claims.

#### Feature guide
See [`Sources/Passage/Features/Linking/README.md`](./Sources/Passage/Features/Linking/README.md) for the automatic vs. manual flows, candidate-matching rules, and state storage.

#### Example
_No dedicated example yet — see [rozd/passage-example](https://github.com/rozd/passage-example) for the canonical walkthrough._
</details>

<details>
<summary><h3>📋 Views</h3> — server-rendered Leaf templates for login, registration, password reset, magic link, account linking, and passkeys.</summary>

#### Configuration
```swift
Passage.Configuration(
    // ... other config ...
    views: .init(
        login: .init(
            style: .material,
            theme: .init(colors: .oceanLight),
            redirect: .init(onSuccess: "/dashboard"),
            identifier: .email
        ),
        register: .init(
            style: .material,
            theme: .init(colors: .oceanLight),
            identifier: .email
        ),
        passwordResetRequest: .init(style: .material, theme: .init(colors: .oceanLight)),
        passwordResetConfirm: .init(style: .material, theme: .init(colors: .oceanLight)),
        magicLinkRequest: .init(style: .material, theme: .init(colors: .oceanLight)),
        magicLinkVerify: .init(
            style: .material,
            theme: .init(colors: .oceanLight),
            redirect: .init(onSuccess: "/dashboard")
        ),
        linkAccountSelect: .init(style: .material, theme: .init(colors: .oceanLight)),
        linkAccountVerify: .init(style: .material, theme: .init(colors: .oceanLight))
    )
)
```

Four styles ship (`.neobrutalism`, `.neomorphism`, `.minimalism`, `.material`) and 17 color palettes with light/dark variants. Views are registered only when configured — omit a view key to skip the corresponding GET route.

#### Feature guide
See [`Sources/Passage/Features/Views/README.md`](./Sources/Passage/Features/Views/README.md) for the full view list, theme options, and custom-color recipes.

#### Example
_No dedicated example yet — see [rozd/passage-example](https://github.com/rozd/passage-example) for the canonical walkthrough._
</details>

<div align="center">

# Passage
[![Release](https://img.shields.io/github/v/release/vapor-community/passage?style=plastic&logo=github&logoColor=ccc)](https://github.com/vapor-community/passage/releases)
[![Swift 6.3+](https://design.vapor.codes/images/swift63up.svg)](https://swift.org)
[![License](https://design.vapor.codes/images/mitlicense.svg)](./LICENSE)
[![Continous integration](https://img.shields.io/github/actions/workflow/status/vapor-community/passage/ci.yml?event=push&style=plastic&logo=github&label=tests&logoColor=ccc)](https://github.com/vapor-community/passage/actions/workflows/ci.yml)
[![Code coverage](https://img.shields.io/codecov/c/github/vapor-community/passage?style=plastic&logo=codecov&label=codecov)](https://codecov.io/gh/vapor-community/passage)

</div>

A comprehensive identity management and authentication framework for Vapor applications built with Swift. Passage provides secure authentication with minimal configuration while remaining highly extensible through protocol-based architecture.

## Status: Alpha
Use with caution. The library is functional, but the API is subject to change before the stable release.

## Features

- 🔐 **User Registration & Login** - Complete authentication flow with secure password hashing
- 🚦 **Rate Limiting** - Throttling of failed login attempts per account and per source
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
- 🪝 **Lifecycle Hooks** - Async will/did callbacks for custom policy and audit, including a transactional credential-issuance hook
- 🗂️ **Session Inventory** - Stable `sid` claim across refresh, session-scoped revocation, and a host-provided revocation check
- 🎨 **Fully Customizable** - Configure routes, tokens, templates, and behavior

## Standards Compliance

Passage targets [**NIST SP 800-63B Authenticator Assurance Level 1 (AAL1)**](https://pages.nist.gov/800-63-3-Implementation-Resources/63B/AAL/), and ships an executable compliance suite at [`Tests/PassageTests/AAL1/`](./Tests/PassageTests/AAL1/) that pins behavior to specific spec clauses. Coverage spans memorized secrets (§5.1.1), session management (§7.1), reauthentication (§4.1.3 / §7.2), and online-guessing throttling (§5.2.2) — every test name cites the clause it asserts, so the suite doubles as a machine-checked compliance ledger.

## Getting Started

### Installation

Add Passage to your `Package.swift`:

```swift
dependencies: [
    // 🛂 Authentication and user management for Vapor.
    .package(url: "https://github.com/vapor-community/passage.git", from: "0.3.0"),
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
- **Lifecycle Hooks** - Inject async pre/post callbacks around authentication flows; throw from `will*` hooks to gate flows on custom policy, or from `willIssueCredential` to roll a sign-in back inside the store transaction

## Services to Implement

Passage exposes six service protocols for pluggable backends. Only `Store` is required; every other service is optional and unlocks a related feature when provided. Each section below links to [DEVELOPER_NOTES.md](./DEVELOPER_NOTES.md) for protocol signatures, sub-protocol breakdowns, invariants, and integration recipes.

<details>
<summary><h3>🗄️ Store</h3> (Required) — persists users, tokens, verification codes, magic links, and passkey records.</summary>

#### Recommended implementation:
[passage-fluent](https://github.com/rozd/passage-fluent) — a Fluent-backed `DatabaseStore` with ready-made migrations for PostgreSQL, MySQL, and SQLite. For tests, use `Passage.OnlyForTest.InMemoryStore`, which ships in this repo.

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

`PasskeyService` is the single seam between Passage core and a concrete WebAuthn library — core has **zero** WebAuthn-library dependencies and talks only through this protocol. Providing a `PasskeyService` is the one gate that enables every passkey route; Passage additionally needs `Store.passkeyCredentials` and `Store.passkeyChallenges` sub-stores to be non-nil. `PassageFluent.DatabaseStore` will gain these alongside the upcoming passage-fluent model work; `Passage.OnlyForTest.InMemoryStore` already includes them for tests.

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

<details>
<summary><h3>🚦 Throttle</h3> (Optional) — rate-limits failed authentication attempts per account and per source, per NIST SP 800-63B §5.2.2.</summary>

#### Recommended implementation:
`Passage.Throttle.InMemoryService` ships with Passage and is used unless you override it. It's a sliding-window counter implemented as a Swift `actor` — safe under concurrent login traffic on a single instance. For deployments that run multiple app instances behind a load balancer, supply a shared backend (e.g. Redis-backed) so counters aren't fragmented across nodes; otherwise an attacker can spread attempts across replicas to sidestep per-node caps.

`Passage.Throttle.Service` has three methods: `check(bucket:against:at:)` decides allowed vs. throttled, `penalize(bucket:at:)` records a failed attempt, and `reset(bucket:)` clears a bucket on successful authentication. Buckets key by `(scope, dimension, enabled)` where `dimension` is either `.identifier(kind:value:)` (per-account) or `.source(String)` (per IP / forwarded address).

#### Implementation guide:
See [`Sources/Passage/Services/Passage+Throttle.swift`](./Sources/Passage/Services/Passage+Throttle.swift) for the protocol surface and [`Sources/Passage/LoginThrottleMiddleware.swift`](./Sources/Passage/LoginThrottleMiddleware.swift) for how it's wired into the login route.
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
<summary><h3>🚦 Throttling</h3> — rate-limits failed login attempts per account and per source, per NIST SP 800-63B §5.2.2.</summary>

#### Service setup
Uses `Passage.Throttle.Service`. The default `Passage.Throttle.InMemoryService` is provided automatically — no setup required for single-instance deployments. See the [Services chapter](#services-to-implement) for how to override with a shared backend (Redis, DB) when running multiple app instances.

#### Configuration
```swift
Passage.Configuration(
    // ... other config ...
    throttle: .init(
        login: .init(
            perIdentifier: .init(maxFailures: 10, window: 15 * 60),   // 10 failures / 15 min per account
            perSource: .init(maxFailures: 20, window: 15 * 60),       // 20 failures / 15 min per IP
            enabled: true
        )
    )
)
```

Over-limit requests return **`429 Too Many Requests`** with a `Retry-After` header (seconds until the oldest in-window attempt ages out). A successful login clears both counters for that account and source (§5.2.2-c). Form-validation failures (e.g. missing password) count toward the per-source bucket — the throttle middleware runs ahead of form decoding so malformed requests can't sidestep the counter.

**Per-identifier** (account) protects against sustained guessing on one account. **Per-source** protects against credential-stuffing sprays across many accounts. The defaults trip well before §5.2.2-b's 100-attempt ceiling while leaving honest users plenty of room for typos.

#### Feature guide
Configuration: [`Sources/Passage/Configuration/Configuration+Throttle.swift`](./Sources/Passage/Configuration/Configuration+Throttle.swift). Middleware: [`Sources/Passage/LoginThrottleMiddleware.swift`](./Sources/Passage/LoginThrottleMiddleware.swift). Per-identifier enforcement lives in the login service at [`Sources/Passage/Features/Account/Passage+Account.swift`](./Sources/Passage/Features/Account/Passage+Account.swift).

#### Example
_No dedicated example yet — see [rozd/passage-example](https://github.com/rozd/passage-example) for the canonical walkthrough._
</details>

<details>
<summary><h3>🗂️ Session inventory in the host</h3> — record every live credential in your own tables, atomically with issuance.</summary>

#### Configuration
A host that keeps its own session inventory — list a user's devices, revoke one of them, including a credential that was never used after sign-in — used to learn about a new credential only by inspecting the HTTP response after Passage had already committed it. That is a dual write. If the host's bookkeeping fails, either the login answers 5xx while the token is already live (the client retries and mints more live tokens), or the host swallows the error and the token exists outside its inventory until its first authenticated request. Both are wrong, and neither is fixable from outside Passage. Two things remove the dual write: an issuance hook that runs **inside** the store transaction, and a stable session id (`sid`) that names the refresh-token family.

```swift
try await app.passage.configure(
    services: .init(/* ... */),
    configuration: .init(/* ... */),
    hooks: .init(
        account: .hook(
            willIssueCredential: { issuance, request in
                let db = (issuance.store as? DatabaseStore)?.database ?? request.db
                try await HostSession(
                    id: issuance.sessionId,
                    userId: try issuance.user.requiredIdAsString,
                    kind: issuance.kind == .bearer ? "bearer" : "browser",
                    expiresAt: issuance.refreshTokenExpiresAt,
                    device: request.headers.first(name: .userAgent)
                ).save(on: db)
                try await HostSession.query(on: db)
                    .filter(\.$id ~~ issuance.revokedSessionIds)
                    .set(\.$revokedAt, to: .now)
                    .update()
            },
            didIssueCredential: { issuance, request in
                try? await analytics.track(.signIn, origin: issuance.origin, user: issuance.user)
            },
            isSessionRevoked: { sessionId, request in
                (try? await HostSession.find(sessionId, on: request.db))?.revokedAt != nil
            }
        )
    )
)
```

**`willIssueCredential(_:on:)`** runs after the access token is signed and the refresh-token row is written, inside the same store transaction, before commit. A throw aborts the transaction: no refresh-token row, no credential returned, and the route answers the thrown error. Use `issuance.store` — the transaction-bound store — for your own writes; with PassageFluent that is `(issuance.store as? DatabaseStore)?.database`.

**`didIssueCredential(_:on:)`** runs after commit and cannot throw. Put side effects that must not roll issuance back here (analytics, mail).

Every login issues exactly one credential and fires the hooks exactly once for it. The route decides which credential from the transport the client can use:

| Request                                                           | Credential                                   | `kind`     |
|-------------------------------------------------------------------|----------------------------------------------|------------|
| Form submission accepting `text/html`, with the matching view configured | Cookie session (requires `sessions.enabled`) | `.browser` |
| Anything else (JSON body, no view, API client)                    | JWT + refresh token                          | `.bearer`  |

Password login, magic-link verify, and manual account linking follow this rule. Federated login and passkey authentication set the cookie session for the browser (when sessions are enabled) and hand API clients an exchange code; the later `POST` exchange issues the `.bearer` credential and never touches the cookie. Token refresh is always `.bearer`. A `.bearer` issuance therefore always means the client received those tokens, and a `.browser` issuance always means a cookie was set — there is no discarded credential to filter out.

A browser login while `sessions.enabled` is `false` fails with `PassageError.sessionsDisabled` rather than rendering a success page with no credential behind it: the `login`, `magicLinkVerify`, and `linkAccountVerify` views can only sign a browser in with a cookie.

Hosts that authenticate users from their own routes call the same helper the built-in routes use:

```swift
let user = try await req.passwordless.verifyEmailMagicLink(token: token)
let authUser = try await req.passage.login(user, origin: .magicLink, via: .bearer)
```

`request.passage.login(_:origin:via:sessionId:revokeExisting:)` returns the `AuthUser` for `.bearer` and `nil` for `.browser`.

`CredentialIssuance` fields:

| Field                   | Meaning                                                                                                   |
|-------------------------|-----------------------------------------------------------------------------------------------------------|
| `kind`                  | `.bearer` (JWT + refresh token) or `.browser` (cookie session; token fields are `nil`)                    |
| `origin`                | `.login`, `.magicLink`, `.refresh`, `.exchange`, `.federatedLogin`, `.passkey`, `.accountLinking`          |
| `user`                  | The user the credential belongs to                                                                        |
| `sessionId`             | The `sid`; new on `issue`, carried forward on `refresh`                                                   |
| `accessToken`           | The signed JWT (`.bearer` only)                                                                           |
| `accessTokenExpiresAt`  | `exp` of the JWT (`.bearer` only)                                                                         |
| `refreshTokenExpiresAt` | Expiry of the refresh-token row (`.bearer` only)                                                          |
| `revokedSessionIds`     | Sessions whose refresh tokens this sign-in revoked (see below); retire those rows in the same transaction |
| `store`                 | The store bound to the transaction the hook runs in                                                       |

**`sid`.** Every access token carries a `sid` claim (UUID string) and every refresh-token row stores the same `sessionId`. `issue` mints a new one; `refresh` copies it onto the replacement refresh token and the new access token, so a session keeps its name across rotations. The refresh-token family already existed (`revoke(refreshTokenFamilyStartingFrom:)`); `sid` is its name. Read it on an authenticated request with `request.passage.sessionId` — from the bearer JWT, or from the cookie session for browser logins.

**Revocation.** `try await request.passage.revoke(sessionId:)` revokes the family; the next refresh with any of its tokens fails with `invalidRefreshToken`. To reject an already-issued JWT before its `exp`, or to sign a cookie session out, implement `isSessionRevoked` against your own revocation table — it is consulted by `PassageBearerAuthenticator` on every request whose JWT carries a `sid` and by `PassageSessionAuthenticator` for every cookie session that stored one, is off by default, and keeps Passage from growing a denylist of its own.

**`revokeExisting`.** `issue(for:revokeExisting:)` defaults to `true`: every sign-in revokes all of the user's existing refresh tokens (the magic-link flow exposes this as `revokeExistingTokens` in its configuration). The hook reports the affected sessions in `revokedSessionIds` so your inventory can retire them atomically.

**Transactional guarantee.** `Passage.Store.transaction(_:)` is a required protocol member: `PassageFluent.DatabaseStore` wraps issuance in `database.transaction { … }`, and a custom store must do the equivalent so a throwing hook rolls the refresh-token row back; see [DEVELOPER_NOTES.md](./DEVELOPER_NOTES.md#store).

#### Feature guide
See [`Sources/Passage/Features/Tokens/README.md`](./Sources/Passage/Features/Tokens/README.md) for the claim table and the issue / refresh ordering, and [`Sources/Passage/Types/CredentialIssuance.swift`](./Sources/Passage/Types/CredentialIssuance.swift) for the value type.

#### Example
_No dedicated example yet — see [rozd/passage-example](https://github.com/rozd/passage-example) for the canonical walkthrough._
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
        jwks: try .fileFromEnvironment()                        // JWKS file path from `JWKS_FILE_PATH`
    ),
    routes: .init(
        refreshToken: .init(path: "refresh-token"),             // POST /auth/refresh-token
        exchangeCode: .init(path: "exchange")                   // POST /auth/exchange
    )
)
```

**JWKS loading** — `JWKS.fileFromEnvironment()` reads the JWKS payload from the file path in `JWKS_FILE_PATH`. If you want to load the JWKS payload directly from the `JWKS` environment variable, use `JWKS.environment()` instead:

```bash
export JWKS_FILE_PATH="/path/to/jwks.json"
# or
export JWKS='{"keys":[...]}'
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
        routes: .init(
            guestRegistrationBegin: .default,   // opt-in: enables public guest signup
            guestRegistrationFinish: .default
        ),
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

The two `guestRegistration*` routes are opt-in — pass `.default` to enable public passkey signup, omit them to require all enrollments to go through the authenticated `/registration/*` flow. The two `registration*` routes (authenticated enrollment) are always registered behind `PassageGuard`.

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

<details>
<summary><h3>🪝 Hooks</h3> — async lifecycle callbacks fired around authentication flows.</summary>

#### Configuration
Hooks are an optional fourth parameter on `app.passage.configure(...)`, alongside `services`, `contracts`, and `configuration`:

```swift
try await app.passage.configure(
    services: .init(/* ... */),
    configuration: .init(/* ... */),
    hooks: .init(
        account: .hook(
            didRegisterUser: { user, request in
                request.logger.info("registered \(user.id ?? "?")")
            },
            willLoginUser: { user, request in
                guard !user.isSuspended else {
                    throw Abort(.forbidden, reason: "Account suspended")
                }
            },
            didLoginUser: { user, request in
                try? await analytics.track(.login, user: user)
            }
        )
    )
)
```

Hook protocols expose `will*` / `did*` pairs around each flow. `will*` methods are `async throws` and abort the flow when they throw; `did*` methods are non-throwing observers that fire after the underlying step has succeeded. All methods have empty default implementations, so a custom hook type only overrides the events it cares about. The `.hook(...)` factory shown above is convenient for ad-hoc wiring; for richer behavior conform a type to the protocol directly.

**`Passage.Hooks.Account`** — Account flows (register / login / logout) and credential issuance:

| Hook                  | Fires…                                                                                              |
|-----------------------|-----------------------------------------------------------------------------------------------------|
| `willRegister`        | Before password validation and user creation                                                        |
| `didRegister`         | After user creation, before the verification code is dispatched                                     |
| `willLogin`           | After credentials succeed, before the session is established                                        |
| `didLogin`            | After the session is established, before access tokens are issued                                   |
| `willLogout`          | Before the session is cleared                                                                       |
| `didLogout`           | After the session is cleared, before the refresh token is revoked                                   |
| `willIssueCredential` | Inside the store transaction, after the refresh-token row is written, before commit — throw to abort |
| `didIssueCredential`  | After the transaction commits; non-throwing                                                         |
| `isSessionRevoked`    | On every bearer request whose JWT carries a `sid`; return `true` to reject it with 401              |

`willLogin` fires **after** the password check passes — it is the gate where you enforce post-authentication policy (account suspension, license expiry, forced MFA), not credential validation.

**`Passage.Hooks.Passkey`** — Passkey ceremonies (guest registration, authenticated registration, authentication). `will*` hooks for the finish path fire **after** the binding / TOCTOU / signature checks, so handlers see only ceremonies that will succeed and audit logs are not attributed to victims on hijack attempts.

| Hook                              | Fires…                                                                   |
|-----------------------------------|--------------------------------------------------------------------------|
| `willBeginGuestRegistration`      | After identifier-already-registered check, before the WebAuthn service   |
| `didBeginGuestRegistration`       | After the challenge is persisted (guest flow)                            |
| `willBeginRegistration`           | Before the WebAuthn service runs (authenticated flow)                    |
| `didBeginRegistration`            | After the challenge is persisted (authenticated flow)                    |
| `willFinishGuestRegistration`     | After the TOCTOU identifier check, before user creation                  |
| `willFinishRegistration`          | After the bound-user equality check passes (authenticated flow)          |
| `didFinishGuestRegistration`      | After the credential is persisted and challenge consumed (guest flow)    |
| `didFinishRegistration`           | After the credential is persisted and challenge consumed (authenticated) |
| `willBeginAuthentication`         | After the discoverable-login policy check, before the WebAuthn service   |
| `didBeginAuthentication`          | After the authentication challenge is persisted                          |
| `willFinishAuthentication`        | After signature verification + user resolution, before sign-count update / challenge consumption / login (auth-equivalent of `Account.willLogin` — gate suspended accounts, MFA step-up, etc.) |
| `didFinishAuthentication`         | After the session is established and the exchange code minted            |

`Passage.Hooks` covers Account and Passkey today and is shaped to grow additional domains over time.

#### Feature guide
See [`Sources/Passage/Hooks/Passage+Hooks.swift`](./Sources/Passage/Hooks/Passage+Hooks.swift) for the container struct, [`Sources/Passage/Hooks/Hooks+Account.swift`](./Sources/Passage/Hooks/Hooks+Account.swift) for the `Account` protocol, and [`Sources/Passage/Hooks/Hooks+Passkey.swift`](./Sources/Passage/Hooks/Hooks+Passkey.swift) for the `Passkey` protocol — each ships default implementations and a `.hook(...)` factory.

#### Example
_No dedicated example yet — see [rozd/passage-example](https://github.com/rozd/passage-example) for the canonical walkthrough._
</details>

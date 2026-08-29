# Passage — Service Implementation Notes

This document describes how to implement each of Passage's service protocols yourself.

The main [README](./README.md) gives a high-level overview of which services exist and which are optional. The per-feature guides under [`Sources/Passage/Features/*/README.md`](./Sources/Passage/Features/) describe HTTP routes, DTOs, and ceremony flows. This file is the missing middle: the protocol surface and invariants a custom backend has to satisfy.

All service types live under the `Passage` namespace (e.g. `Passage.Store`, `Passage.EmailDelivery`) and are wired in via `app.passage.configure(services:configuration:)`.

## Table of contents

- [Store](#store)
- [Email Delivery](#email-delivery)
- [Phone Delivery](#phone-delivery)
- [Federated Login Service](#federated-login-service)
- [Passkey Service](#passkey-service)
- [Random Generator](#random-generator)

---

## Store

**Protocol:** [`Sources/Passage/Services/Passage+Store.swift`](./Sources/Passage/Services/Passage+Store.swift)

`Passage.Store` is a composite that exposes eight sub-stores — one per persistence concern. The last two (`passkeyCredentials`, `passkeyChallenges`) are optional and default to `nil`; supply them only when you enable passkeys.

```swift
public protocol Store: Sendable {
    var users: any UserStore { get }
    var tokens: any TokenStore { get }
    var verificationCodes: any VerificationCodeStore { get }
    var restorationCodes: any RestorationCodeStore { get }
    var magicLinkTokens: any MagicLinkTokenStore { get }
    var exchangeTokens: any ExchangeTokenStore { get }
    var passkeyCredentials: (any PasskeyCredentialStore)? { get }  // default nil
    var passkeyChallenges: (any PasskeyChallengeStore)? { get }    // default nil

    func transaction<T: Sendable>(
        _ body: @Sendable (any Store) async throws -> T
    ) async throws -> T
}
```

### Transactions

`transaction(_:)` is how Passage makes credential issuance atomic: `Passage.Tokens.issue` / `refresh` revoke prior tokens, write the new refresh-token row, and call `Passage.Hooks.Account.willIssueCredential` inside one call to `transaction`, and only commit if the hook returns. Wrap `body` in your database's transaction and hand it a store bound to that transaction; if `body` throws, roll back so the hook's failure leaves no refresh-token row behind.

A transactional store must:

- open a database transaction and hand `body` a store whose every sub-store is bound to it (in `PassageFluent.DatabaseStore` this is `database.transaction { tx in body(self.bound(to: tx)) }`);
- commit when `body` returns and roll back when it throws, rethrowing the error;
- tolerate nested calls — sub-store methods such as `createRefreshToken(..., replacing:)` may open their own transaction on the bound database, which must join the outer one rather than start a new one (Fluent's SQL drivers do this).

The store handed to `body` is the one the hook receives as `CredentialIssuance.store`, so a host can cast it back to your concrete type to reach the underlying connection.

### Sub-stores

| Sub-store | Responsibility |
|---|---|
| `UserStore` | User CRUD, identifier lookup, password rotation, account linking (`addIdentifier`), passwordless-only creators (`createWithEmail`, `createWithPhone`). |
| `TokenStore` | Refresh-token rows with rotation chain (`createRefreshToken(..., sessionId:replacing:)`), family revocation (`revoke(refreshTokenFamilyStartingFrom:)`), session-scoped revocation (`revokeRefreshTokens(sessionId:)`), user-wide revocation that reports which sessions it retired (`revokeRefreshTokens(for:) -> [UUID]`), and session-selective revocation for concurrency policies (`revokeRefreshTokens(for:keepingNewestSessions:) -> [UUID]`). |
| `VerificationCodeStore` | Email + phone verification codes (create/find/invalidate/increment-failed). |
| `RestorationCodeStore` | Email + phone password-reset codes (same shape as verification). |
| `MagicLinkTokenStore` | Passwordless email magic-link tokens with optional `sessionTokenHash` for same-browser enforcement. |
| `ExchangeTokenStore` | Short-TTL (≈60 s) one-shot codes used by federated login + passkey authentication handoff. |
| `PasskeyCredentialStore` | W3C credential records (credentialID, COSE public key, sign count, transports, backup state, AAGUID, attestation format). |
| `PasskeyChallengeStore` | One-shot WebAuthn challenges — **store the SHA-256 hash of the raw bytes**, never the bytes themselves. |

### Invariants

- **Hash, don't store plaintext.** Every token and code is persisted as a SHA-256 hash. Refresh tokens, verification codes, reset codes, magic-link tokens, exchange tokens, and passkey challenges all follow this rule. The caller hashes before handing bytes to most sub-stores; `PasskeyChallengeStore` is the one exception — it receives raw `PasskeyChallenge.bytes` and hashes internally (e.g. via a `Data.sha256Hex` helper) so that plain challenge bytes never reach the database layer.
- **One-shot consumption.** `ExchangeToken`s and `StoredPasskeyChallenge`s must set a `consumedAt` timestamp on use and reject subsequent reads. Cleanup methods (`cleanupExpiredTokens(before:)`, `cleanupExpiredPasskeyChallenges(before:)`) let you run periodic sweeps.
- **Refresh-token family revocation.** Token rotation links the old token's `replacedBy` field to the new row. On reuse (i.e. a rotated-away hash is presented again), follow the chain and revoke the entire family via `revoke(refreshTokenFamilyStartingFrom:)`.
- **Session ids name the family.** `RefreshToken.sessionId` is the `sid` claim of the access tokens minted with that row; every row in a rotation chain shares it. Persist the value passed to `createRefreshToken(for:tokenHash:expiresAt:sessionId:replacing:)` — the parameter is required (non-optional `UUID`). `revokeRefreshTokens(for:)` must return the distinct session ids of the rows it flipped. `revokeRefreshTokens(sessionId:)` revokes all refresh tokens for a given session. To support `revokeRefreshTokens(for:keepingNewestSessions:)` for concurrency policies, persist a `createdAt` timestamp on each refresh-token row and order sessions by the creation time of their newest live row (most recently active first).
- **Eager loading.** When `UserStore.find(byIdentifier:)` is called, load the identifier's user along with its other identifiers if you need account-linking semantics — otherwise downstream features (federated login, linking, passkeys) will issue extra queries per request.

### Reference implementations

- **[passage-fluent](https://github.com/rozd/passage-fluent)** — `DatabaseStore` backs all eight sub-stores with Fluent models and ships migrations for PostgreSQL, MySQL, and SQLite. The recommended production choice.
- **`Passage.OnlyForTest.InMemoryStore`** — Ships in this repo under the `PassageOnlyForTest` product. Full in-memory implementation of every sub-store; use for tests only.

---

## Email Delivery

**Protocol:** [`Sources/Passage/Services/Passage+EmailDelivery.swift`](./Sources/Passage/Services/Passage+EmailDelivery.swift)

```swift
public protocol EmailDelivery: Sendable {
    func sendEmailVerification(
        to email: String,
        user: any User,
        verificationURL: URL,
        verificationCode: String
    ) async throws

    func sendEmailVerificationConfirmation(
        to email: String,
        user: any User
    ) async throws

    func sendPasswordResetEmail(
        to email: String,
        user: any User,
        passwordResetURL: URL,
        passwordResetCode: String
    ) async throws

    func sendWelcomeEmail(
        to email: String,
        user: any User
    ) async throws

    func sendMagicLinkEmail(
        to email: String,
        user: (any User)?,  // nil for new users on passwordless signup
        magicLinkURL: URL
    ) async throws
}
```

### Notes

- Passage hands you fully-constructed URLs for verification, reset, and magic-link flows — no path construction on your side.
- `sendMagicLinkEmail` receives a nil `user` when a brand-new user signs up via magic link with auto-create enabled; template accordingly.
- Template selection and HTML rendering are entirely your responsibility. The default HTML templates Passage ships with (under `Resources/EmailTemplates/`) are consumed by the built-in Mailgun integration — you can reuse them or replace them.
- Delivery is typically dispatched through a Vapor Queue (`SendEmailCodeJob`, etc.) when `useQueues: true` is set in the verification/restoration configuration. Your implementation just needs to send; the job wrapping is handled by Passage.

### Reference implementation

**[passage-mailgun](https://github.com/rozd/passage-mailgun)** — Mailgun-backed implementation. Configure with API key, default domain, and sender identity:

```swift
import PassageMailgun

let emailDelivery = MailgunEmailDelivery(
    app: app,
    configuration: .init(
        mailgun: .init(
            apiKey: "your-mailgun-api-key",
            defaultDomain: .init("mg.example.com", .us)
        ),
        sender: .init(
            email: "noreply@mg.example.com",
            name: "No Reply"
        )
    )
)
```

For other providers (SES, Postmark, Sendgrid), implement `Passage.EmailDelivery` directly against the provider SDK.

---

## Phone Delivery

**Protocol:** [`Sources/Passage/Services/Passage+PhoneDelivery.swift`](./Sources/Passage/Services/Passage+PhoneDelivery.swift)

```swift
public protocol PhoneDelivery: Sendable {
    func sendPhoneVerification(
        to phone: String,
        code: String,
        user: any User
    ) async throws

    func sendVerificationConfirmation(
        to phone: String,
        user: any User
    ) async throws

    func sendPasswordResetSMS(
        to phone: String,
        code: String,
        user: any User
    ) async throws
}
```

### Notes

- SMS messages carry a raw code, not a URL — authenticators typed on mobile shouldn't require clicking links.
- Message formatting (brand prefix, language, length) is entirely your implementation's job.
- Queue dispatch works the same way as email delivery: set `useQueues: true` in the relevant verification/restoration config.

### Reference implementation

No companion package ships yet. Implement against Twilio, AWS SNS, Vonage, or your SMS gateway of choice:

```swift
struct TwilioPhoneDelivery: Passage.PhoneDelivery {
    let client: TwilioClient

    func sendPhoneVerification(to phone: String, code: String, user: any User) async throws {
        try await client.send(to: phone, body: "Your code: \(code)")
    }

    func sendVerificationConfirmation(to phone: String, user: any User) async throws {
        // optional
    }

    func sendPasswordResetSMS(to phone: String, code: String, user: any User) async throws {
        try await client.send(to: phone, body: "Reset code: \(code)")
    }
}
```

---

## Federated Login Service

**Protocol:** [`Sources/Passage/Services/Passage+FederatedLoginService.swift`](./Sources/Passage/Services/Passage+FederatedLoginService.swift)

```swift
public protocol FederatedLoginService: Sendable {
    func register(
        router: any RoutesBuilder,
        origin: URL,
        group: [PathComponent],
        config: Passage.Configuration.FederatedLogin,
        onSignIn: @escaping @Sendable (
            _ request: Request,
            _ identity: FederatedIdentity
        ) async throws -> some AsyncResponseEncodable
    ) throws
}
```

### Notes

- The single `register(router:origin:group:config:onSignIn:)` method is unusual among the service protocols: it gives the implementation full control to attach provider routes onto Passage's router group. That's why OAuth integration is a "bring a whole subsystem" service rather than a collection of method hooks.
- Your implementation is responsible for:
  - Registering routes like `/auth/login/:provider` and `/auth/login/:provider/callback`.
  - Constructing redirect URIs from `origin` + `group`.
  - Negotiating the OAuth dance (auth code, token exchange, userinfo).
  - Normalizing each provider's userinfo payload into `FederatedIdentity` (provider, providerUserID, email, optional name).
- The `onSignIn` closure fires when the callback has resolved the identity. Passage uses this callback to reconcile against `UserStore` (linking, account-matching, creating) and to mint the exchange code that the client swaps for an access token.

### Reference implementation

**[passage-imperial](https://github.com/rozd/passage-imperial)** — Uses the [Imperial](https://github.com/vapor-community/Imperial) OAuth library. GitHub, Google, and custom providers are all supported via Imperial's `FederatedServiceTokens`:

```swift
import PassageImperial

try await app.passage.configure(
    services: .init(
        store: store,
        federatedLogin: ImperialFederatedLoginService(
            services: [
                .github          : GitHub.self,
                .named("google") : Google.self,
            ]
        )
    ),
    configuration: .init(
        origin: URL(string: "https://api.example.com")!,
        federatedLogin: .init(
            routes: .init(),
            providers: [
                .github(credentials: .conventional),
                .google(credentials: .conventional, scope: ["profile", "email"])
            ]
        )
    )
)
```

See [`Sources/Passage/Features/FederatedLogin/README.md`](./Sources/Passage/Features/FederatedLogin/README.md) for the on-the-wire route shape and exchange-code handshake.

---

## Passkey Service

**Protocol:** [`Sources/Passage/Services/Passage+PasskeyService.swift`](./Sources/Passage/Services/Passage+PasskeyService.swift)

`PasskeyService` is the single seam between Passage core and a concrete WebAuthn library. Passage core has **zero** dependencies on any WebAuthn implementation — it talks only to this protocol.

```swift
public protocol PasskeyService: Sendable {
    func beginRegistration(
        with user: PublicKeyCredentialUserEntity,
        policy: Passage.Configuration.Passkey.Policy,
        challengeTTL: TimeInterval
    ) async throws -> PasskeyBeginResult

    func finishRegistration(
        rawBody: Data,
        policy: Passage.Configuration.Passkey.Policy,
        lookupChallenge: @Sendable (_ challengeBytes: Data) async throws -> (any StoredPasskeyChallenge)?,
        confirmUnused: @Sendable (_ credentialID: String) async throws -> Bool
    ) async throws -> PasskeyFinishRegistrationResult

    func beginAuthentication(
        allowCredentials: [PasskeyCredentialDescriptor]?,
        policy: Passage.Configuration.Passkey.Policy,
        challengeTTL: TimeInterval
    ) async throws -> PasskeyBeginResult

    func finishAuthentication(
        rawBody: Data,
        policy: Passage.Configuration.Passkey.Policy,
        lookupChallenge: @Sendable (_ challengeBytes: Data) async throws -> (any StoredPasskeyChallenge)?,
        lookupCredential: @Sendable (_ credentialID: String) async throws -> (any StoredPasskeyCredential)?
    ) async throws -> PasskeyFinishAuthenticationResult
}
```

### Notes

- **Relying Party identity lives on the service.** `relyingPartyID`, `relyingPartyName`, and `relyingPartyOrigin` are configured on the underlying WebAuthn backend (e.g. `WebAuthnManager.Configuration`) — *not* on `Passage.Configuration.Passkey`. `Passage.Configuration.Passkey` controls policy (timeout, attestation, userVerification, algorithms, discoverable-login toggle), challenge TTL, and route paths only.
- **Opaque response bodies.** `PasskeyBeginResult.body` is typed as `any AsyncResponseEncodable & Sendable`. Core encodes it directly into the HTTP response without inspecting it, which is what keeps the WebAuthn types out of core.
- **Challenge lookup is caller-provided.** `finishRegistration` and `finishAuthentication` both take a `lookupChallenge` closure the service must invoke with raw bytes extracted from `clientDataJSON`. The closure is wired to `PasskeyChallengeStore.find(passkeyChallengeMatching:)`, which hashes the bytes before querying — so the service never sees the hash and the store never sees the plaintext.
- **`confirmUnused` for registration.** On `finishRegistration`, the service calls `confirmUnused(credentialID)` to enforce that the credential ID hasn't been registered before. This closure forwards directly to `swift-webauthn`'s `confirmCredentialIDNotRegisteredYet:` API when using the reference implementation.
- **Post-authentication bookkeeping.** `PasskeyFinishAuthenticationResult.newSignCount` and `.credentialBackedUp` should be written back via `PasskeyCredentialStore.updatePasskeyCredentialAfterAuthentication(...)`. Sign-count regression is an anti-cloning heuristic — log or reject at your discretion.

### Reference implementation

**[passage-webauthn](https://github.com/rozd/passage-webauthn)** wraps [swift-webauthn](https://github.com/swift-server/webauthn-swift). Configure the Relying Party on `WebAuthnManager.Configuration`:

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

try await app.passage.configure(
    services: .init(
        store: store,           // must supply passkeyCredentials + passkeyChallenges
        passkey: passkeyService
    ),
    configuration: .init(
        origin: URL(string: "https://example.com")!,
        passkey: .init(
            policy: .init(
                timeout: .seconds(60),
                attestation: .none,
                userVerification: .preferred,
                supportedAlgorithms: [.ES256, .RS256],
                allowDiscoverableLogin: true      // required for the sign-in ceremony
            )
        )
    )
)
```

See [`Sources/Passage/Features/Passkey/README.md`](./Sources/Passage/Features/Passkey/README.md) for the three ceremony flows (guest registration / authenticated registration / authentication), full route + DTO reference, and flow diagrams.

---

## Random Generator

**Protocol:** [`Sources/Passage/Services/Passage+Random.swift`](./Sources/Passage/Services/Passage+Random.swift)

```swift
public protocol RandomGenerator: Sendable {
    func generateRandomString(count: Int) -> String
    func generateOpaqueToken() -> String
    func hashOpaqueToken(token: String) -> String
    func generateVerificationCode(length: Int) -> String
}
```

### Notes

- `DefaultRandomGenerator` ships with Passage and is used unless you override. It uses `SHA256` from `CryptoKit` for hashing and `[UInt8].random` for entropy.
- Verification codes use a **restricted alphabet** — `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` — to eliminate the visual ambiguity of `0/O` and `1/I/L`. Keep this alphabet if users will ever type the code manually.
- Opaque tokens returned by `generateOpaqueToken` are 32-byte base64 strings — long enough that guessing is not a practical attack. `hashOpaqueToken` produces a lowercase hex SHA-256, which is what the various `TokenStore.find(...Hash:)` methods expect.
- Override this service only if you need different code formats (e.g. numeric-only codes for IVR flows) or stricter cryptographic guarantees. Most apps should leave the default in place.

```swift
struct NumericVerificationCodeGenerator: Passage.RandomGenerator {
    func generateRandomString(count: Int) -> String { /* … */ }
    func generateOpaqueToken() -> String            { /* … */ }
    func hashOpaqueToken(token: String) -> String   { /* … */ }

    func generateVerificationCode(length: Int) -> String {
        String((0..<length).map { _ in "0123456789".randomElement()! })
    }
}
```

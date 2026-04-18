# Configuration

Central configuration for all Passage features.

## Quick Start

```swift
try await app.passage.configure(
    services: .init(store: myStore),
    configuration: try .init(
        origin: URL(string: "https://myapp.com")!,
        routes: .init(group: "auth"),
        tokens: .init(accessTokenTTL: 900, refreshTokenTTL: 604800),
        jwt: .init(jwks: try .fileFromEnvironment())
    )
)
```

## Configuration Sections

| Section | File | Purpose |
|---------|------|---------|
| `routes` | `Configuration+Routes.swift` | API endpoint paths |
| `tokens` | `Configuration+Tokens.swift` | Token TTLs and settings |
| `sessions` | `Configuration+Sessions.swift` | Session authentication |
| `jwt` | `Configuration+JWT.swift` | JWKS for signing tokens |
| `verification` | `Configuration+Verification.swift` | Email/phone verification |
| `restoration` | `Configuration+Restoration.swift` | Password reset |
| `passwordless` | `Configuration+Passwordless.swift` | Magic links |
| `federatedLogin` | `Configuration+FederatedLogin.swift` | OAuth providers |
| `passkey` | `Configuration+Passkey.swift` | WebAuthn / FIDO2 passkeys (optional, default `nil`) |
| `views` | `Configuration+Views.swift` | Server-rendered UI |

## Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `origin` | `URL` | Base URL for callbacks and links |
| `jwt` | `JWT` | JWKS configuration (defaults to `JWKS_FILE_PATH` env var) |

## Routes

Default base path: `/auth`

| Route | Default Path | Customization |
|-------|--------------|---------------|
| Register | `/auth/register` | `routes: .init(register: .init(path: "signup"))` |
| Login | `/auth/login` | `routes: .init(login: .init(path: "signin"))` |
| Logout | `/auth/logout` | `routes: .init(logout: .init(path: "signout"))` |
| Refresh | `/auth/refresh-token` | `routes: .init(refreshToken: .init(path: "refresh"))` |
| Exchange | `/auth/token/exchange` | `routes: .init(exchangeCode: .init(path: "exchange"))` |
| Current User | `/me` | `routes: .init(currentUser: .init(path: "user"))` |

## JWT/JWKS

Three ways to load JWKS:

```swift
// From environment variable JWKS_FILE_PATH (default)
jwt: .init(jwks: try .fileFromEnvironment())

// From specific environment variable
jwt: .init(jwks: try .environment(name: "MY_JWKS"))

// From file path
jwt: .init(jwks: try .file(path: "/path/to/jwks.json"))
```

## Sessions

Enable session-based authentication for server-rendered views:

```swift
sessions: .init(enabled: true)
```

## Feature Documentation

Each configuration section is documented in its feature README:

- [Account](../Features/Account/README.md) - Routes configuration
- [Tokens](../Features/Tokens/README.md) - Token TTLs
- [Verification](../Features/Verification/README.md) - Email/phone verification config
- [Restoration](../Features/Restoration/README.md) - Password reset config
- [Passwordless](../Features/Passwordless/README.md) - Magic link config
- [Federated Login](../Features/FederatedLogin/README.md) - OAuth config
- [Passkey](../Features/Passkey/README.md) - WebAuthn config (RP, challenge TTL, policy)
- [Views](../Features/Views/README.md) - UI config

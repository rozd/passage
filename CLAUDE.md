# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Passage is a Swift package providing identity management for Vapor applications. It handles user authentication (register, login, logout), JWT access/refresh tokens, email/phone verification, password reset flows, and federated OAuth login (Google, GitHub, custom providers).

## Build Commands

```bash
swift build           # Build the package
swift test            # Run tests (no tests exist yet)
```

## Architecture

### Core Types

- **Passage** (`Passage.swift`) - Main entry point, configured via `app.passage.configure(services:configuration:)`. Registers route collections and jobs.

- **User** protocol (`User.swift`) - Apps implement this to define their user model. Requires `id`, `email`, `phone`, `username`, `passwordHash`, `isAnonymous`, `isEmailVerified`, `isPhoneVerified`.

- **Passage.Services** (`Passage+Services.swift`) - Dependency container holding:
  - `Store` - protocol with sub-stores (`UserStore`, `TokenStore`, `CodeStore`, `ResetCodeStore`)
  - `EmailDelivery` / `PhoneDelivery` - protocols for sending verification codes
  - `RandomGenerator` - code/token generation
  - `FederatedLoginService` - OAuth provider integration

- **Passage.Configuration** (`Passage+Configuration.swift`) - Extensive configuration for routes, token TTLs, JWT/JWKS, verification/restoration settings, and OAuth providers.

### Authentication Flow

1. **Register** - Creates user with hashed password, auto-sends verification code
2. **Login** - Validates credentials, issues JWT access token + opaque refresh token
3. **Refresh** - Exchanges refresh token for new access/refresh pair (token rotation with family revocation)
4. **Logout** - Revokes refresh token

### Tokens (`Tokens.swift`)

- `AccessToken` - JWT with standard claims (`sub`, `exp`, `iat`, `iss`, `aud`, `scope`)
- `RefreshToken` - Protocol for opaque tokens stored hashed, supports rotation via `replacedBy` chain

### Verification (`Passage+Verification.swift`)

Handles email/phone verification codes. Supports sync delivery or async via Vapor Queues (`SendEmailCodeJob`, `SendPhoneCodeJob`).

### Restoration (`Passage+Restoration.swift`)

Password reset flows for email/phone. Similar pattern to verification with queued job support.

### Identifiers & Credentials

- `Identifier` - enum-like struct with `Kind` (.email, .phone, .username) and value
- `Credential` - registration credential pairing identifier with password hash

### Route Collections

- `PassageRouteCollection` - Core auth routes (register, login, logout, refresh-token, me)
- `EmailVerificationRouteCollection` / `PhoneVerificationRouteCollection` - Verification endpoints
- `EmailRestorationRouteCollection` / `PhoneRestorationRouteCollection` - Password reset endpoints
- `PasswordResetFormRouteCollection` - Web form for password reset (Leaf template)

### Resources

- `Resources/EmailTemplates/` - HTML email templates
- `Resources/Views/` - Leaf templates for web forms

## Key Patterns

- **Protocol-based storage**: Apps provide their own `Store` implementation (e.g., Fluent-backed)
- **Configurable routes**: All route paths are customizable via `Configuration.Routes`
- **Optional queues**: Set `useQueues: true` in verification/restoration config to dispatch jobs async
- **JWKS configuration**: Load from environment (`JWKS`) or file path (`JWKS_FILE_PATH`)

## Compatibility Policy (IMPORTANT)

Passage is **pre-release**. Breaking changes are welcome; do **not** add backward-compatibility shims (no forwarding defaults on protocol extensions, no deprecated aliases, no dual code paths). When a change breaks a protocol or public type, make it cleanly and list the concrete updates required in each implementor — `passage-fluent`, `passage-imperial`, `passage-mailgun`, and custom stores (`DEVELOPER_NOTES.md`) — under a **Breaking** heading in `CHANGELOG.md`.

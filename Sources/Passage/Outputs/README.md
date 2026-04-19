# Outputs

Response types for API endpoints.

## Types

| Type | Description |
|------|-------------|
| `AuthUser` | Authentication response with tokens and user info |
| `PasskeyRegistrationResponse` | Response body for `POST /passkey/register/finish` |
| `PasskeyAuthenticationResponse` | Response body for `POST /passkey/authenticate/finish` |

## AuthUser

Returned from login, register, and token refresh endpoints:

```swift
struct AuthUser: Content {
    let accessToken: String      // JWT access token
    let refreshToken: String     // Opaque refresh token
    let tokenType: String        // "Bearer"
    let expiresIn: TimeInterval  // Access token TTL in seconds
    let user: User               // User info (id, email, phone)
}
```

### AuthUser.User

Nested user info structure:

```swift
struct User: Content, UserInfo {
    let id: String
    let email: String?
    let phone: String?
}
```

## Passkey

`Outputs/Passkey/` currently holds:

| Type | Description |
|------|-------------|
| `PasskeyRegistrationResponse` | `{ credentialID: String }` — returned on `201 Created` from the registration finish endpoint |
| `PasskeyAuthenticationResponse` | `{ code: String }` — returned on `200 OK` from the authentication finish endpoint. The `code` is an opaque exchange token minted via `Passage.Tokens.createExchangeCode(for:)`, the same primitive the OAuth completion flow uses. |

The `PublicKeyCredentialCreationOptions` / `PublicKeyCredentialRequestOptions` JSON bodies returned by the two *begin* endpoints are **not** defined here. They are produced by the configured `PasskeyService` implementation (e.g. `swift-webauthn`'s native options types via `passage-webauthn`) and flow through the orchestration as `any AsyncResponseEncodable & Sendable` so the core package never has to model the WebAuthn wire format. See [Features/Passkey](../Features/Passkey/README.md).

The corresponding service-layer result types (`PasskeyBeginResult`, `PasskeyFinishRegistrationResult`, `PasskeyFinishAuthenticationResult`) live next to the `PasskeyService` protocol in `Services/Passage+PasskeyService.swift` rather than here.

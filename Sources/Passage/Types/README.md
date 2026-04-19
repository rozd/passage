# Types

Value types and domain objects.

## Core types

| Type | Description |
|------|-------------|
| `AccessToken` | JWT access token payload with standard claims |
| `IdToken` | JWT ID token with user info claims (future use) |
| `Identifier` | User identifier (email, phone, username, or federated) |
| `Credential` | User credential (password hash) |
| `FederatedProvider` | OAuth provider configuration |
| `FederatedIdentity` | OAuth identity with verified emails/phones |
| `LinkingResolution` | Account linking strategy (disabled, automatic, manual) |

## Passkey / WebAuthn types

Service → store DTOs live at the top level of `Types/`; W3C spec types live in
the `Passkey/` subdirectory alongside their Passage-specific extensions.

| Type | File | Description |
|------|------|-------------|
| `PasskeyCredential` | `PasskeyCredential.swift` | Verified passkey record (service → store DTO) |
| `PasskeyChallenge` | `PasskeyChallenge.swift` | Freshly-issued passkey challenge (service → store DTO) |
| `PasskeyChallengeKind` | `PasskeyChallenge.swift` | `.registration` or `.authentication` |
| `PasskeyCredentialDescriptor` | `Passkey/WebAuthn.swift` | Hint for the browser's credential picker during authentication |
| `PublicKeyCredentialEntity` | `Passkey/WebAuthn.swift` | Common protocol for RP and user entities |
| `PublicKeyCredentialRpEntity` | `Passkey/WebAuthn.swift` | WebAuthn Relying Party identity (name + id) |
| `PublicKeyCredentialUserEntity` | `Passkey/WebAuthn.swift` | WebAuthn user handle (id + name + displayName); `Passkey/WebAuthn+Passage.swift` adds an `init(with:displayName:)` over `Identifier` |
| `COSEAlgorithmIdentifier` | `Passkey/WebAuthn.swift` | Int-raw-value COSE algorithm (ES256 = −7, RS256 = −257, …) |
| `AuthenticatorTransport` | `Passkey/WebAuthn.swift` | `.usb`, `.nfc`, `.ble`, `.internal`, `.hybrid`, `.smartcard`, `.unknown(…)` |
| `UserVerificationRequirement` | `Passkey/WebAuthn.swift` | `.required`, `.preferred`, `.discouraged` |
| `AttestationConveyancePreference` | `Passkey/WebAuthn.swift` | `.none`, `.direct`, `.indirect`, `.enterprise` |

## AccessToken

JWT payload with claims: `sub`, `exp`, `iat`, `iss`, `aud`, `scope`

## Identifier

```swift
struct Identifier {
    let kind: Kind      // .email, .phone, .username, .federated
    let value: String
    let provider: FederatedProvider.Name?  // Only for federated
}
```

Static constructors: `.email(_:)`, `.phone(_:)`, `.username(_:)`, `.federated(_:userId:)`

## FederatedProvider

```swift
struct FederatedProvider {
    let name: Name           // e.g., .google, .github
    let credentials: Credentials  // .conventional or .client(id:secret:)
    let scope: [String]
}
```

Static constructors: `.google()`, `.github()`, `.custom(name:)`

## FederatedIdentity

OAuth identity returned from provider callback:

```swift
struct FederatedIdentity {
    let identifier: Identifier
    let provider: FederatedProvider.Name
    let verifiedEmails: [String]
    let verifiedPhoneNumbers: [String]
    let displayName: String?
    let profilePictureURL: String?
}
```

## LinkingResolution

```swift
enum LinkingResolution {
    case disabled
    case automatic(matchBy: [Identifier.Kind], onAmbiguity: AmbiguityResolution)
    case manual(matchBy: [Identifier.Kind])
}
```

## PasskeyCredential

Verified passkey record produced by `PasskeyService.finishRegistration(...)` and persisted via `PasskeyCredentialStore.createPasskeyCredential(for:from:)`:

```swift
struct PasskeyCredential {
    let credentialID: String        // base64url
    let publicKey: Data             // COSE_Key bytes
    let signCount: UInt32
    let uvInitialized: Bool
    let transports: [AuthenticatorTransport]
    let backupEligible: Bool
    let isBackedUp: Bool
    let aaguid: String?
    let attestationFormat: String?
}
```

## PasskeyChallenge

Freshly-issued challenge from `PasskeyService.beginRegistration(...)`; persisted via `PasskeyChallengeStore.createPasskeyChallenge(for:from:)`. Store implementations SHA-256 the raw bytes before writing — the plaintext challenge never reaches the database.

```swift
struct PasskeyChallenge {
    let bytes: Data                 // raw challenge
    let kind: PasskeyChallengeKind  // .registration or .authentication
    let expiresAt: Date
}
```

See [Features/Passkey](../Features/Passkey/README.md) for how these DTOs are used end-to-end.

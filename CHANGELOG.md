# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Versions are git tags; the release workflow reads the latest tag.

## [Unreleased]

### Added

- `Passage.Configuration.Tokens.RefreshToken.Concurrency` enum to control how many concurrent refresh-token sessions a user may hold: `.unlimited` (any number, default), `.single` (one per user), `.limit(n)` (up to `n` most recently active).
- `Passage.TokenStore.revokeRefreshTokens(for:keepingNewestSessions:) -> [UUID]` — enforces concurrency policy by revoking all but the `n` most recently active sessions; a session's recency is decided by the creation time of its newest live token.

### Changed

- Token issuance now enforces the configured concurrency policy automatically. The `revokeExisting` parameter is removed from `issue(for:sessionId:origin:)`.
- Default token behavior is now `.unlimited` concurrent sessions (users may hold any number of sessions), changing from the previous "revoke all on each login" behavior. Configure `.single` or `.limit(n)` to restore multi-device limitations.
- `refresh` never triggers session eviction, even under `.single` or `.limit(n)`. Only new authentications (login, OAuth exchange) can trigger revocation.

### Breaking

- `issue(for:sessionId:revokeExisting:origin:)` becomes `issue(for:sessionId:origin:)`. Concurrency is controlled via `tokens.refreshToken.concurrency` configuration instead.
- `PassageContext.login(_:origin:via:sessionId:revokeExisting:)` becomes `login(_:origin:via:sessionId:)`.
- `Passage.Configuration.Passwordless.revokeExistingTokens` removed; session concurrency is now configured on `tokens.refreshToken.concurrency`.
- Required implementor changes:
  - **passage-fluent** — `TokenStore.revokeRefreshTokens(for:keepingNewestSessions:)` must be implemented by ordering refresh-token rows within each session by `created_at` (most recent first) and revoking all but the first `count` sessions.
  - **custom stores** — implement the new method by persisting a creation timestamp on each refresh-token row and ordering sessions by their newest row's creation time.
  - **passage-imperial**, **passage-mailgun** — unaffected.

## [0.6.0] - 2026-08-28

### Added

- `CredentialIssuance` value type describing a minted credential: `kind` (`.bearer` / `.browser`), `origin` (`.login`, `.magicLink`, `.refresh`, `.exchange`, `.federatedLogin`, `.passkey`, `.accountLinking`), `user`, `sessionId`, `accessToken`, `accessTokenExpiresAt`, `refreshTokenExpiresAt`, `revokedSessionIds`, and the transaction-bound `store`.
- `Passage.Hooks.Account.willIssueCredential(_:on:)` — runs inside the store transaction after the refresh-token row is written and before commit; a throw rolls the issuance back. `didIssueCredential(_:on:)` runs after commit. Both have no-op defaults and closure forms on `.hook(...)`.
- `Passage.Hooks.Account.isSessionRevoked(_:on:)` — host-provided check consulted by `PassageBearerAuthenticator` for every JWT that carries a `sid`; returning `true` answers 401 `AuthenticationError.sessionRevoked`. Off by default.
- `sid` claim on `AccessToken` (`public let sessionId: UUID`) and `RefreshToken.sessionId` (required non-optional `UUID`). `issue` mints a session id; `refresh` carries it onto the replacement refresh token and the new access token.
- `request.passage.sessionId` — the current session id from the bearer JWT or the cookie session.
- `request.passage.revoke(sessionId:)` — revokes the refresh-token family; the next refresh fails with `invalidRefreshToken`.
- `Passage.Store.transaction(_:)`; `Passage.TokenStore.createRefreshToken(for:tokenHash:expiresAt:sessionId:replacing:)`, `revokeRefreshTokens(for:) -> [UUID]`, and `revokeRefreshTokens(sessionId:)`.
- `Passage.OnlyForTest.InMemoryStore.transaction` snapshots and restores refresh-token rows so hook failures roll back in tests; `InMemoryTokenStore.refreshTokens` lists rows.
- README section "Session inventory in the host" and matching notes in the Tokens feature guide and `DEVELOPER_NOTES.md`.

### Changed

- Every path that mints a credential (password login, magic-link verify, exchange code, token refresh) now writes the refresh token and runs `willIssueCredential` inside `Store.transaction`.
- Every login issues exactly one credential, chosen by the route from the client's transport: a form submission accepting `text/html` with the matching view configured gets a `.browser` cookie session; everything else gets a `.bearer` JWT + refresh token. `willIssueCredential`/`didIssueCredential` fire once per login. Previously a login with `sessions.enabled` minted both, leaving an unused refresh-token row behind for HTML clients and setting a cookie for JSON clients.
- `POST` exchange-code no longer sets a cookie session; the OAuth or passkey callback already did, and the exchange previously overwrote its stored session id.
- `PassageSessionAuthenticator` consults `isSessionRevoked` with the cookie session's id and signs the session out when the host answers `true`.
- `issue(for:revokeExisting:)` keeps its default of revoking all of the user's refresh tokens on each sign-in; the affected sessions are now reported to the hook as `revokedSessionIds`.
- `AuthenticationError` gained `.sessionRevoked` (401).

### Breaking

- `RefreshToken.sessionId` is now a required non-optional `UUID` (was `UUID?` with `nil` default). All refresh tokens must carry a session id.
- `AccessToken.sessionId` is now a required non-optional `UUID` parameter in the init (was `UUID? = nil`). All access tokens must carry a `sid` claim.
- `Passage.TokenStore.createRefreshToken(for:tokenHash:expiresAt:sessionId:)` requires `sessionId: UUID` (non-optional). The overloads without `sessionId` have been removed.
- `Passage.Store.transaction(_:)` is a required protocol member; the best-effort default that ran `body(self)` without rollback has been removed.
- `Passage.Passwordless.verifyEmailMagicLink(token:)` returns `any User` instead of `AuthUser`. Hosts calling it from their own routes issue the credential with the new public `request.passage.login(_:origin:via:sessionId:revokeExisting:) -> AuthUser?` (`via: .bearer` returns the `AuthUser`; `via: .browser` sets the cookie and returns `nil`).
- New `Passage.Transport` (`.browser`, `.bearer`).
- A browser login (`via: .browser`, which the `login`, `magicLinkVerify`, and `linkAccountVerify` views trigger) with `sessions.enabled == false` throws `PassageError.sessionsDisabled` instead of rendering a success page without setting any credential.
- JSON clients no longer receive a session cookie alongside tokens when sessions are enabled; a browser that needs a cookie submits the form with `Accept: text/html`.
- Required implementor changes:
  - **passage-fluent** — `DatabaseStore` must implement `transaction(_:)` via `database.transaction { … }`; `RefreshTokenModel.sessionId` becomes a required `UUID` field with a non-nullable `session_id` column; `DatabaseStore`'s token sub-store adopts the `sessionId: UUID` signatures of `createRefreshToken`. Existing `refresh_tokens` rows without a session id cannot be represented — the migration should delete (or revoke) them, which signs those sessions out.
  - **custom stores** — same protocol changes; see `DEVELOPER_NOTES.md` › Store.
  - **passage-imperial**, **passage-mailgun** — unaffected.

### Migration notes

- Access tokens issued before this change carry no `sid` and no longer decode; clients must re-authenticate. Refresh-token rows without a session id must be dropped by the store's migration (see Breaking).

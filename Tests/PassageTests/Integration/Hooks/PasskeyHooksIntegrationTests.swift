import Foundation
import JWT
import NIOFoundationCompat
@testable import Passage
@testable import PassageOnlyForTest
import Testing
import Vapor
import VaporTesting

@Suite(.tags(.integration, .hooks, .passkey))
struct `Passkey Hooks Integration Tests` {

    // MARK: - Fixtures

    private struct PolicyError: AbortError {
        let status: HTTPResponseStatus = .forbidden
        let reason: String
    }

    private static let sharedChallengeBytes = MockPasskeyService.sharedChallengeBytes
    private static let sharedCredentialID = "credential-id-mock"

    private static let minimalRegisterFinishBody = #"{"id":"any","type":"public-key","rawId":"any","response":{"clientDataJSON":"","attestationObject":"","transports":["internal"]}}"#
    private static let minimalAuthFinishBody = #"{"id":"credential-id-mock","rawId":"credential-id-mock","type":"public-key","response":{"clientDataJSON":"","authenticatorData":"","signature":""}}"#

    final class HookSpy: @unchecked Sendable {
        // Begin
        var willBeginGuestRegistration: [String] = []   // identifier values
        var didBeginGuestRegistration: Int = 0
        var willBeginRegistration: [String] = []        // user ids
        var didBeginRegistration: [String] = []
        var willBeginAuthentication: Int = 0
        var didBeginAuthentication: Int = 0

        // Finish
        var willFinishGuestRegistration: [String?] = [] // identifier values (or nil)
        var didFinishGuestRegistration: [String] = []   // user ids
        var willFinishRegistration: [String?] = []      // user ids (or nil)
        var didFinishRegistration: [String] = []
        var willFinishAuthentication: [(credentialID: String, userId: String)] = []
        var didFinishAuthentication: [(credentialID: String, userId: String, codeIsEmpty: Bool)] = []

        // Throws-on-will controls
        var willBeginGuestRegistrationError: (any Error)?
        var willFinishGuestRegistrationError: (any Error)?
        var willBeginRegistrationError: (any Error)?
        var willFinishRegistrationError: (any Error)?
        var willBeginAuthenticationError: (any Error)?
        var willFinishAuthenticationError: (any Error)?

        func makeHook() -> any Passage.Hooks.Passkey {
            _PasskeyHooksClosures.hook(
                willBeginGuestRegistration: { [self] form, _, _ in
                    let id = try form.asIdentifier()
                    willBeginGuestRegistration.append(id.value)
                    if let err = willBeginGuestRegistrationError { throw err }
                },
                didBeginGuestRegistration: { [self] _, _ in
                    didBeginGuestRegistration += 1
                },
                willFinishGuestRegistration: { [self] identifier, _ in
                    willFinishGuestRegistration.append(identifier?.value)
                    if let err = willFinishGuestRegistrationError { throw err }
                },
                didFinishGuestRegistration: { [self] _, user, _ in
                    didFinishGuestRegistration.append((try? user.requiredIdAsString) ?? "")
                },

                willBeginRegistration: { [self] user, _, _ in
                    willBeginRegistration.append((try? user.requiredIdAsString) ?? "")
                    if let err = willBeginRegistrationError { throw err }
                },
                didBeginRegistration: { [self] _, user, _ in
                    didBeginRegistration.append((try? user.requiredIdAsString) ?? "")
                },
                willFinishRegistration: { [self] user, _ in
                    willFinishRegistration.append(try? user?.requiredIdAsString)
                    if let err = willFinishRegistrationError { throw err }
                },
                didFinishRegistration: { [self] _, user, _ in
                    didFinishRegistration.append((try? user.requiredIdAsString) ?? "")
                },

                willBeginAuthentication: { [self] _ in
                    willBeginAuthentication += 1
                    if let err = willBeginAuthenticationError { throw err }
                },
                didBeginAuthentication: { [self] _, _ in
                    didBeginAuthentication += 1
                },
                willFinishAuthentication: { [self] credential, user, _ in
                    willFinishAuthentication.append((
                        credential.credentialID,
                        (try? user.requiredIdAsString) ?? ""
                    ))
                    if let err = willFinishAuthenticationError { throw err }
                },
                didFinishAuthentication: { [self] credential, user, code, _ in
                    didFinishAuthentication.append((
                        credential.credentialID,
                        (try? user.requiredIdAsString) ?? "",
                        code.isEmpty
                    ))
                }
            )
        }
    }

    final class Holder: @unchecked Sendable {
        var store: Passage.OnlyForTest.InMemoryStore?
        var seededUser: (any User)?
    }

    /// Shared configuration: enables guest registration routes, seeds the
    /// store with a user + credential + auth-flow challenge so authentication
    /// finish has something to resolve.
    @Sendable private func configure(
        _ app: Application,
        holder: Holder,
        spy: HookSpy,
        seedAuthChallenge: Bool = true,
        seedGuestChallenge: Bool = false
    ) async throws {
        await app.jwt.keys.add(
            hmac: HMACKey(from: "test-secret-key-for-jwt-signing"),
            digestAlgorithm: .sha256,
            kid: JWKIdentifier(string: "test-key")
        )

        let store = Passage.OnlyForTest.InMemoryStore()
        holder.store = store

        let services = Passage.Services(
            store: store,
            random: DefaultRandomGenerator(),
            emailDelivery: Passage.OnlyForTest.MockEmailDelivery(),
            phoneDelivery: Passage.OnlyForTest.MockPhoneDelivery(),
            federatedLogin: nil,
            passkey: MockPasskeyService()
        )

        let configuration = try Passage.Configuration(
            origin: URL(string: "http://localhost:8080")!,
            tokens: .init(
                issuer: "test-issuer",
                accessToken: .init(timeToLive: 3600),
                refreshToken: .init(timeToLive: 86400)
            ),
            jwt: .init(jwks: .init(json: #"{"keys":[]}"#)),
            verification: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: false
            ),
            restoration: .init(
                email: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                phone: .init(codeLength: 6, codeExpiration: 600, maxAttempts: 5),
                useQueues: false
            ),
            passkey: .init(
                routes: .init(
                    guestRegistrationBegin: .default,
                    guestRegistrationFinish: .default
                )
            )
        )

        try await app.passage.configure(
            services: services,
            configuration: configuration,
            hooks: .init(passkey: spy.makeHook())
        )

        if seedAuthChallenge {
            let user = try await store.users.create(
                identifier: .email("alice@example.com"),
                with: nil
            )
            holder.seededUser = user

            if let credentials = store.passkeyCredentials {
                _ = try await credentials.createPasskeyCredential(
                    for: user,
                    from: PasskeyCredential(
                        credentialID: Self.sharedCredentialID,
                        publicKey: Data([0x04, 0xDE, 0xAD]),
                        signCount: 0,
                        uvInitialized: false,
                        transports: [.internal],
                        backupEligible: false,
                        isBackedUp: false,
                        aaguid: nil,
                        attestationFormat: nil
                    )
                )
            }
            if let challenges = store.passkeyChallenges {
                _ = try await challenges.createPasskeyChallenge(
                    from: PasskeyChallenge(
                        bytes: Self.sharedChallengeBytes,
                        kind: .authentication,
                        expiresAt: Date().addingTimeInterval(300)
                    )
                )
            }
        }

        if seedGuestChallenge, let challenges = store.passkeyChallenges {
            _ = try await challenges.createPasskeyChallenge(
                for: .email("bob@example.com"),
                from: PasskeyChallenge(
                    bytes: Self.sharedChallengeBytes,
                    kind: .registration,
                    expiresAt: Date().addingTimeInterval(300)
                )
            )
        }
    }

    // MARK: - Authentication: begin

    @Test
    func `willBeginAuthentication and didBeginAuthentication fire on POST begin`() async throws {
        let spy = HookSpy()
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, spy: spy, seedAuthChallenge: false)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/begin",
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .ok)
            }
        }

        #expect(spy.willBeginAuthentication == 1)
        #expect(spy.didBeginAuthentication == 1)
    }

    @Test
    func `willBeginAuthentication aborts the flow when it throws`() async throws {
        let spy = HookSpy()
        spy.willBeginAuthenticationError = PolicyError(reason: "rate-limited")

        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, spy: spy, seedAuthChallenge: false)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/begin",
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .forbidden)
            }
        }

        // didBegin must NOT fire when willBegin throws.
        #expect(spy.willBeginAuthentication == 1)
        #expect(spy.didBeginAuthentication == 0)

        // No challenge should have been persisted.
        let challenges = try #require(holder.store?.passkeyChallenges)
        let stored = try await challenges.find(passkeyChallengeMatching: Self.sharedChallengeBytes)
        #expect(stored == nil)
    }

    // MARK: - Authentication: finish

    @Test
    func `willFinishAuthentication and didFinishAuthentication fire on POST finish`() async throws {
        let spy = HookSpy()
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, spy: spy)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalAuthFinishBody)
            ) { res in
                #expect(res.status == .ok)
            }
        }

        let user = try #require(holder.seededUser)
        let userId = try user.requiredIdAsString

        #expect(spy.willFinishAuthentication.count == 1)
        #expect(spy.willFinishAuthentication.first?.credentialID == Self.sharedCredentialID)
        #expect(spy.willFinishAuthentication.first?.userId == userId)

        #expect(spy.didFinishAuthentication.count == 1)
        let did = try #require(spy.didFinishAuthentication.first)
        #expect(did.credentialID == Self.sharedCredentialID)
        #expect(did.userId == userId)
        #expect(did.codeIsEmpty == false)
    }

    @Test
    func `willFinishAuthentication aborts the flow before sign-count update or challenge consumption`() async throws {
        let spy = HookSpy()
        spy.willFinishAuthenticationError = PolicyError(reason: "account suspended")

        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, spy: spy)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/authentication/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalAuthFinishBody)
            ) { res in
                #expect(res.status == .forbidden)
            }
        }

        // willFinish fired exactly once; didFinish never fired.
        #expect(spy.willFinishAuthentication.count == 1)
        #expect(spy.didFinishAuthentication.isEmpty)

        // Challenge must not have been consumed — the user can retry once
        // the policy that blocked them lifts.
        let challenges = try #require(holder.store?.passkeyChallenges)
        let stored = try #require(try await challenges.find(passkeyChallengeMatching: Self.sharedChallengeBytes))
        #expect(stored.isConsumed == false)

        // Sign-count must not have been bumped.
        let credentials = try #require(holder.store?.passkeyCredentials)
        let credential = try #require(try await credentials.find(byCredentialID: Self.sharedCredentialID))
        #expect(credential.signCount == 0)
    }

    // MARK: - Guest Registration: fire ordering across both phases

    @Test
    func `guest registration fires willBegin and didBegin (and finish hooks) in order`() async throws {
        let spy = HookSpy()
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, spy: spy, seedAuthChallenge: false)
        }) { app in
            // Begin ceremony — issues a challenge for charlie@example.com.
            try await app.testing().test(
                .POST, "/auth/passkey/guest/registration/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "email=charlie@example.com&displayName=Charlie")
            ) { res in
                #expect(res.status == .ok)
            }
            // Finish ceremony.
            try await app.testing().test(
                .POST, "/auth/passkey/guest/registration/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalRegisterFinishBody)
            ) { res in
                #expect(res.status == .created)
            }
        }

        #expect(spy.willBeginGuestRegistration == ["charlie@example.com"])
        #expect(spy.didBeginGuestRegistration == 1)
        #expect(spy.willFinishGuestRegistration == ["charlie@example.com"])
        #expect(spy.didFinishGuestRegistration.count == 1)
    }

    // MARK: - Guest Registration: aborts

    @Test
    func `willBeginGuestRegistration aborts the flow when it throws`() async throws {
        let spy = HookSpy()
        spy.willBeginGuestRegistrationError = PolicyError(reason: "signups disabled")

        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, spy: spy, seedAuthChallenge: false)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/guest/registration/begin",
                headers: [
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json"
                ],
                body: .init(string: "email=charlie@example.com&displayName=Charlie")
            ) { res in
                #expect(res.status == .forbidden)
            }
        }

        #expect(spy.willBeginGuestRegistration == ["charlie@example.com"])
        #expect(spy.didBeginGuestRegistration == 0)

        // No challenge should have been persisted.
        let challenges = try #require(holder.store?.passkeyChallenges)
        let stored = try await challenges.find(passkeyChallengeMatching: Self.sharedChallengeBytes)
        #expect(stored == nil)
    }

    @Test
    func `willFinishGuestRegistration aborts before user creation and credential persistence`() async throws {
        let spy = HookSpy()
        spy.willFinishGuestRegistrationError = PolicyError(reason: "verification required")

        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, spy: spy, seedAuthChallenge: false, seedGuestChallenge: true)
        }) { app in
            try await app.testing().test(
                .POST, "/auth/passkey/guest/registration/finish",
                headers: ["Content-Type": "application/json"],
                body: .init(string: Self.minimalRegisterFinishBody)
            ) { res in
                #expect(res.status == .forbidden)
            }
        }

        #expect(spy.willFinishGuestRegistration == ["bob@example.com"])
        #expect(spy.didFinishGuestRegistration.isEmpty)

        // No user should have been created from the challenge identifier.
        let store = try #require(holder.store)
        let materialised = try await store.users.find(byIdentifier: .email("bob@example.com"))
        #expect(materialised == nil)

        // Challenge stays unconsumed.
        let challenges = try #require(holder.store?.passkeyChallenges)
        let challenge = try #require(try await challenges.find(passkeyChallengeMatching: Self.sharedChallengeBytes))
        #expect(challenge.isConsumed == false)

        // No credential persisted.
        let credentials = try #require(holder.store?.passkeyCredentials)
        let credential = try await credentials.find(byCredentialID: Self.sharedCredentialID)
        #expect(credential == nil)
    }

    // MARK: - Authenticated Registration: fixtures

    @Sendable private func createUserAndLogin(
        app: Application,
        email: String,
        password: String = "password123"
    ) async throws -> (user: any User, token: String) {
        let store = app.passage.storage.services.store
        let passwordHash = try await app.password.async.hash(password)
        let user = try await store.users.create(
            identifier: .email(email),
            with: .password(passwordHash)
        )
        try await store.users.markEmailVerified(for: user)

        var accessToken = ""
        try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
            try req.content.encode(["email": email, "password": password])
        }, afterResponse: { res async throws in
            #expect(res.status == .ok)
            let authUser = try res.content.decode(AuthUser.self)
            accessToken = authUser.accessToken
        })
        return (user, accessToken)
    }

    // MARK: - Authenticated Registration: fire ordering

    @Test
    func `authenticated registration fires all four hooks in order`() async throws {
        let spy = HookSpy()
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, spy: spy, seedAuthChallenge: false)
        }) { app in
            let (user, token) = try await self.createUserAndLogin(app: app, email: "alice@example.com")
            let userId = try user.requiredIdAsString

            try await app.testing().test(
                .POST, "/auth/passkey/registration/begin",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .ok)
            }

            try await app.testing().test(
                .POST, "/auth/passkey/registration/finish",
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: .init(string: Self.minimalRegisterFinishBody)
            ) { res in
                #expect(res.status == .created)
            }

            #expect(spy.willBeginRegistration == [userId])
            #expect(spy.didBeginRegistration == [userId])
            #expect(spy.willFinishRegistration == [userId])
            #expect(spy.didFinishRegistration == [userId])
        }
    }

    // MARK: - Authenticated Registration: aborts

    @Test
    func `willBeginRegistration aborts the flow when it throws`() async throws {
        let spy = HookSpy()
        spy.willBeginRegistrationError = PolicyError(reason: "passkey enrollment disabled")

        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, spy: spy, seedAuthChallenge: false)
        }) { app in
            let (user, token) = try await self.createUserAndLogin(app: app, email: "alice@example.com")
            let userId = try user.requiredIdAsString

            try await app.testing().test(
                .POST, "/auth/passkey/registration/begin",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .forbidden)
            }

            #expect(spy.willBeginRegistration == [userId])
            #expect(spy.didBeginRegistration.isEmpty)

            // No challenge persisted.
            let challenges = try #require(holder.store?.passkeyChallenges)
            let stored = try await challenges.find(passkeyChallengeMatching: Self.sharedChallengeBytes)
            #expect(stored == nil)
        }
    }

    @Test
    func `willFinishRegistration aborts before credential persistence and challenge consumption`() async throws {
        let spy = HookSpy()
        let holder = Holder()
        try await withApp(configure: { app in
            try await self.configure(app, holder: holder, spy: spy, seedAuthChallenge: false)
        }) { app in
            let (user, token) = try await self.createUserAndLogin(app: app, email: "alice@example.com")
            let userId = try user.requiredIdAsString

            // Run begin to seed the challenge bound to the authenticated user.
            try await app.testing().test(
                .POST, "/auth/passkey/registration/begin",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: .init(string: "{}")
            ) { res in
                #expect(res.status == .ok)
            }

            // Now arm the spy to abort the finish.
            spy.willFinishRegistrationError = PolicyError(reason: "MFA step-up required")

            try await app.testing().test(
                .POST, "/auth/passkey/registration/finish",
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(token)"
                ],
                body: .init(string: Self.minimalRegisterFinishBody)
            ) { res in
                #expect(res.status == .forbidden)
            }

            #expect(spy.willFinishRegistration == [userId])
            #expect(spy.didFinishRegistration.isEmpty)

            // Challenge stays unconsumed; no credential persisted.
            let challenges = try #require(holder.store?.passkeyChallenges)
            let challenge = try #require(try await challenges.find(passkeyChallengeMatching: Self.sharedChallengeBytes))
            #expect(challenge.isConsumed == false)

            let credentials = try #require(holder.store?.passkeyCredentials)
            let credential = try await credentials.find(byCredentialID: Self.sharedCredentialID)
            #expect(credential == nil)
        }
    }
}

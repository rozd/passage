import Passage
import Foundation

// MARK: - InMemory Models

extension Passage.OnlyForTest {

    public struct InMemoryUser: User, @unchecked Sendable {
        public var id: String?
        public var email: String?
        public var phone: String?
        public var username: String?
        public var passwordHash: String?
        public var isAnonymous: Bool
        public var isEmailVerified: Bool
        public var isPhoneVerified: Bool

        public var sessionID: String {
            guard let id = id else {
                fatalError("User ID is missing")
            }
            return id
        }
    }

    struct InMemoryRefreshToken: RefreshToken, @unchecked Sendable {
        var id: String?
        var userId: String
        var user: InMemoryUser {
            InMemoryUser(
                id: userId,
                email: nil,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            )
        }
        var tokenHash: String
        var expiresAt: Date
        var revokedAt: Date?
        var replacedBy: String?
    }

    struct InMemoryEmailVerificationCode: EmailVerificationCode, @unchecked Sendable {
        var userId: String
        var user: InMemoryUser {
            InMemoryUser(
                id: userId,
                email: email,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            )
        }
        var email: String
        var codeHash: String
        var expiresAt: Date
        var failedAttempts: Int
    }

    struct InMemoryPhoneVerificationCode: PhoneVerificationCode, @unchecked Sendable {
        var userId: String
        var user: InMemoryUser {
            InMemoryUser(
                id: userId,
                email: nil,
                phone: phone,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            )
        }
        var phone: String
        var codeHash: String
        var expiresAt: Date
        var failedAttempts: Int
    }

    struct InMemoryEmailPasswordResetCode: EmailPasswordResetCode, @unchecked Sendable {
        var userId: String
        var user: InMemoryUser {
            InMemoryUser(
                id: userId,
                email: email,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            )
        }
        var email: String
        var codeHash: String
        var expiresAt: Date
        var failedAttempts: Int
    }

    struct InMemoryPhonePasswordResetCode: PhonePasswordResetCode, @unchecked Sendable {
        var userId: String
        var user: InMemoryUser {
            InMemoryUser(
                id: userId,
                email: nil,
                phone: phone,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            )
        }
        var phone: String
        var codeHash: String
        var expiresAt: Date
        var failedAttempts: Int
    }

    struct InMemoryMagicLinkToken: MagicLinkToken, @unchecked Sendable {
        var userId: String?
        var user: InMemoryUser? {
            guard let userId = userId else { return nil }
            return InMemoryUser(
                id: userId,
                email: identifier.kind == .email ? identifier.value : nil,
                phone: identifier.kind == .phone ? identifier.value : nil,
                username: identifier.kind == .username ? identifier.value : nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            )
        }
        var identifier: Identifier
        var tokenHash: String
        var sessionTokenHash: String?
        var expiresAt: Date
        var failedAttempts: Int
    }

    struct InMemoryExchangeToken: ExchangeToken, @unchecked Sendable {
        var id: String?
        var user: InMemoryUser
        var tokenHash: String
        var expiresAt: Date
        var consumedAt: Date?
        var createdAt: Date?
    }

    // MARK: Passkey

    public struct InMemoryStoredPasskey: StoredPasskeyCredential, @unchecked Sendable {
        public var id: String?
        public var user: Passage.OnlyForTest.InMemoryUser
        public var credentialID: String
        public var publicKey: Data
        public var signCount: UInt32
        public var uvInitialized: Bool
        public var transports: [AuthenticatorTransport]
        public var backupEligible: Bool
        public var isBackedUp: Bool
        public var aaguid: String?
        public var attestationFormat: String?
        public var createdAt: Date?
        public var updatedAt: Date?
    }

    public struct InMemoryStoredPasskeyChallenge: StoredPasskeyChallenge, @unchecked Sendable {
        public var id: String?
        public var user: Passage.OnlyForTest.InMemoryUser?
        public var kind: PasskeyChallengeKind
        public var challengeHash: String
        public var expiresAt: Date
        public var consumedAt: Date?
        public var createdAt: Date?
    }

}

// MARK: - InMemoryUserStore

public extension Passage.OnlyForTest.InMemoryStore {

    final class InMemoryUserStore: Passage.UserStore, @unchecked Sendable {

        public var userType: Passage.OnlyForTest.InMemoryUser.Type { Passage.OnlyForTest.InMemoryUser.self }

        private var users: [String: Passage.OnlyForTest.InMemoryUser] = [:]
        private var identifierIndex: [String: String] = [:] // identifier -> userId

        public func create(
            identifier: Identifier,
            with credential: Credential?
        ) async throws -> any User {
            // Build the identifier key - federated identifiers include provider
            let identifierKey = identifier.kind == .federated
                ? "\(identifier.provider?.description ?? ""):\(identifier.value)"
                : identifier.value

            // Check for duplicate identifier
            if identifierIndex[identifierKey] != nil {
                throw identifier.errorWhenIdentifierAlreadyRegistered
            }

            let userId = UUID().uuidString
            let user = Passage.OnlyForTest.InMemoryUser(
                id: userId,
                email: identifier.kind == .email ? identifier.value : nil,
                phone: identifier.kind == .phone ? identifier.value : nil,
                username: identifier.kind == .username ? identifier.value : nil,
                passwordHash: credential?.secret,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: false
            )
            users[userId] = user
            identifierIndex[identifierKey] = userId

            return user
        }

        public func find(byId id: String) async throws -> (any User)? {
            return users[id]
        }

        public func find(byIdentifier identifier: Identifier) async throws -> (any User)? {
            // Build the same key format as addIdentifier for consistency
            let identifierKey = identifier.kind == .federated
                ? "\(identifier.provider?.description ?? ""):\(identifier.value)"
                : identifier.value

            guard let userId = identifierIndex[identifierKey] else {
                return nil
            }
            return users[userId]
        }

        public func markEmailVerified(for user: any User) async throws {
            guard let userId = user.id?.description else { return }
            users[userId]?.isEmailVerified = true
        }

        public func markPhoneVerified(for user: any User) async throws {
            guard let userId = user.id?.description else { return }
            users[userId]?.isPhoneVerified = true
        }

        public func setPassword(for user: any User, passwordHash: String) async throws {
            guard let userId = user.id?.description else { return }
            users[userId]?.passwordHash = passwordHash
        }

        public func addIdentifier(
            _ identifier: Identifier,
            to user: any User,
            with credential: Credential?
        ) async throws {
            guard let userId = user.id?.description else {
                throw PassageError.unexpected(message: "User ID is missing")
            }

            // Check for duplicate identifier
            let identifierKey = identifier.kind == .federated
                ? "\(identifier.provider?.description ?? ""):\(identifier.value)"
                : identifier.value

            if identifierIndex[identifierKey] != nil {
                throw identifier.errorWhenIdentifierAlreadyRegistered
            }

            // Update user with new identifier if it's a standard type
            guard var existingUser = users[userId] else {
                throw PassageError.unexpected(message: "User not found")
            }

            switch identifier.kind {
            case .email:
                existingUser.email = identifier.value
            case .phone:
                existingUser.phone = identifier.value
            case .username:
                existingUser.username = identifier.value
            case .federated:
                break // Federated identifiers don't update user fields directly
            }

            // Update password if credential provided
            if let credential = credential, credential.kind == .password {
                existingUser.passwordHash = credential.secret
            }

            // Store updated user back in dictionary
            users[userId] = existingUser
            identifierIndex[identifierKey] = userId
        }

        public func createWithEmail(_ email: String, verified: Bool) async throws -> any User {
            // Check for duplicate identifier
            if identifierIndex[email] != nil {
                throw AuthenticationError.emailAlreadyRegistered
            }

            let userId = UUID().uuidString
            let user = Passage.OnlyForTest.InMemoryUser(
                id: userId,
                email: email,
                phone: nil,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: verified,
                isPhoneVerified: false
            )
            users[userId] = user
            identifierIndex[email] = userId
            return user
        }

        public func createWithPhone(_ phone: String, verified: Bool) async throws -> any User {
            // Check for duplicate identifier
            if identifierIndex[phone] != nil {
                throw AuthenticationError.phoneAlreadyRegistered
            }

            let userId = UUID().uuidString
            let user = Passage.OnlyForTest.InMemoryUser(
                id: userId,
                email: nil,
                phone: phone,
                username: nil,
                passwordHash: nil,
                isAnonymous: false,
                isEmailVerified: false,
                isPhoneVerified: verified
            )
            users[userId] = user
            identifierIndex[phone] = userId
            return user
        }
    }

}

// MARK: - InMemoryTokenStore

public extension Passage.OnlyForTest.InMemoryStore {

    final class InMemoryTokenStore: Passage.TokenStore, @unchecked Sendable {

        private var tokens: [String: Passage.OnlyForTest.InMemoryRefreshToken] = [:]

        @discardableResult
        public func createRefreshToken(
            for user: any User,
            tokenHash hash: String,
            expiresAt: Date
        ) async throws -> any RefreshToken {
            return try await createRefreshToken(
                for: user,
                tokenHash: hash,
                expiresAt: expiresAt,
                replacing: nil
            )
        }

        @discardableResult
        public func createRefreshToken(
            for user: any User,
            tokenHash hash: String,
            expiresAt: Date,
            replacing tokenToReplace: (any RefreshToken)?
        ) async throws -> any RefreshToken {
            let tokenId = UUID().uuidString

            // Mark old token as replaced
            if let oldToken = tokenToReplace {
                if let oldHash = oldToken.tokenHash as String?,
                   var existing = tokens[oldHash] {
                    existing.replacedBy = tokenId
                    tokens[oldHash] = existing
                }
            }

            guard let userId = user.id?.description else {
                throw PassageError.unexpected(message: "User ID is missing")
            }

            let token = Passage.OnlyForTest.InMemoryRefreshToken(
                id: tokenId,
                userId: userId,
                tokenHash: hash,
                expiresAt: expiresAt,
                revokedAt: nil,
                replacedBy: nil
            )

            tokens[hash] = token
            return token
        }

        public func find(refreshTokenHash hash: String) async throws -> (any RefreshToken)? {
            return tokens[hash]
        }

        public func revokeRefreshToken(for user: any User) async throws {
            guard let userId = user.id?.description else { return }

            for (hash, var token) in tokens where token.userId == userId {
                token.revokedAt = Date()
                tokens[hash] = token
            }
        }

        public func revokeRefreshToken(withHash hash: String) async throws {
            tokens[hash]?.revokedAt = Date()
        }

        public func revoke(refreshTokenFamilyStartingFrom token: any RefreshToken) async throws {
            var current: (any RefreshToken)? = token

            while let currentToken = current {
                if let hash = currentToken.tokenHash as String? {
                    tokens[hash]?.revokedAt = Date()
                }

                // Follow the chain
                if let replacedById = currentToken.replacedBy?.description,
                   let nextToken = tokens.values.first(where: { $0.id == replacedById }) {
                    current = nextToken
                } else {
                    break
                }
            }
        }
    }

}

// MARK: - InMemoryVerificationStore

public extension Passage.OnlyForTest.InMemoryStore {

    final class InMemoryVerificationStore: Passage.VerificationCodeStore, @unchecked Sendable {

        private var emailCodes: [String: Passage.OnlyForTest.InMemoryEmailVerificationCode] = [:]
        private var phoneCodes: [String: Passage.OnlyForTest.InMemoryPhoneVerificationCode] = [:]

        // MARK: Email Codes

        @discardableResult
        public func createEmailCode(
            for user: any User,
            email: String,
            codeHash: String,
            expiresAt: Date
        ) async throws -> any EmailVerificationCode {
            guard let userId = user.id?.description else {
                throw PassageError.unexpected(message: "User ID is missing")
            }

            let key = "\(email):\(codeHash)"
            let code = Passage.OnlyForTest.InMemoryEmailVerificationCode(
                userId: userId,
                email: email,
                codeHash: codeHash,
                expiresAt: expiresAt,
                failedAttempts: 0
            )
            emailCodes[key] = code
            return code
        }

        public func findEmailCode(
            forEmail email: String,
            codeHash: String
        ) async throws -> (any EmailVerificationCode)? {
            let key = "\(email):\(codeHash)"
            return emailCodes[key]
        }

        public func invalidateEmailCodes(forEmail email: String) async throws {
            emailCodes = emailCodes.filter { !$0.key.hasPrefix("\(email):") }
        }

        public func incrementFailedAttempts(for code: any EmailVerificationCode) async throws {
            let key = "\(code.email):\(code.codeHash)"
            emailCodes[key]?.failedAttempts += 1
        }

        // MARK: Phone Codes

        @discardableResult
        public func createPhoneCode(
            for user: any User,
            phone: String,
            codeHash: String,
            expiresAt: Date
        ) async throws -> any PhoneVerificationCode {
            guard let userId = user.id?.description else {
                throw PassageError.unexpected(message: "User ID is missing")
            }

            let key = "\(phone):\(codeHash)"
            let code = Passage.OnlyForTest.InMemoryPhoneVerificationCode(
                userId: userId,
                phone: phone,
                codeHash: codeHash,
                expiresAt: expiresAt,
                failedAttempts: 0
            )
            phoneCodes[key] = code
            return code
        }

        public func findPhoneCode(
            forPhone phone: String,
            codeHash: String
        ) async throws -> (any PhoneVerificationCode)? {
            let key = "\(phone):\(codeHash)"
            return phoneCodes[key]
        }

        public func invalidatePhoneCodes(forPhone phone: String) async throws {
            phoneCodes = phoneCodes.filter { !$0.key.hasPrefix("\(phone):") }
        }

        public func incrementFailedAttempts(for code: any PhoneVerificationCode) async throws {
            let key = "\(code.phone):\(code.codeHash)"
            phoneCodes[key]?.failedAttempts += 1
        }
    }

}

// MARK: - InMemoryRestorationStore

public extension Passage.OnlyForTest.InMemoryStore {

    final class InMemoryRestorationStore: Passage.RestorationCodeStore, @unchecked Sendable {

        private var emailResetCodes: [String: Passage.OnlyForTest.InMemoryEmailPasswordResetCode] = [:]
        private var phoneResetCodes: [String: Passage.OnlyForTest.InMemoryPhonePasswordResetCode] = [:]

        // MARK: Email Reset Codes

        @discardableResult
        public func createPasswordResetCode(
            for user: any User,
            email: String,
            codeHash: String,
            expiresAt: Date
        ) async throws -> any EmailPasswordResetCode {
            guard let userId = user.id?.description else {
                throw PassageError.unexpected(message: "User ID is missing")
            }

            let key = "\(email):\(codeHash)"
            let code = Passage.OnlyForTest.InMemoryEmailPasswordResetCode(
                userId: userId,
                email: email,
                codeHash: codeHash,
                expiresAt: expiresAt,
                failedAttempts: 0
            )
            emailResetCodes[key] = code
            return code
        }

        public func findPasswordResetCode(
            forEmail email: String,
            codeHash: String
        ) async throws -> (any EmailPasswordResetCode)? {
            let key = "\(email):\(codeHash)"
            return emailResetCodes[key]
        }

        public func invalidatePasswordResetCodes(forEmail email: String) async throws {
            emailResetCodes = emailResetCodes.filter { !$0.key.hasPrefix("\(email):") }
        }

        public func incrementFailedAttempts(for code: any EmailPasswordResetCode) async throws {
            let key = "\(code.email):\(code.codeHash)"
            emailResetCodes[key]?.failedAttempts += 1
        }

        // MARK: Phone Reset Codes

        @discardableResult
        public func createPasswordResetCode(
            for user: any User,
            phone: String,
            codeHash: String,
            expiresAt: Date
        ) async throws -> any PhonePasswordResetCode {
            guard let userId = user.id?.description else {
                throw PassageError.unexpected(message: "User ID is missing")
            }

            let key = "\(phone):\(codeHash)"
            let code = Passage.OnlyForTest.InMemoryPhonePasswordResetCode(
                userId: userId,
                phone: phone,
                codeHash: codeHash,
                expiresAt: expiresAt,
                failedAttempts: 0
            )
            phoneResetCodes[key] = code
            return code
        }

        public func findPasswordResetCode(
            forPhone phone: String,
            codeHash: String
        ) async throws -> (any PhonePasswordResetCode)? {
            let key = "\(phone):\(codeHash)"
            return phoneResetCodes[key]
        }

        public func invalidatePasswordResetCodes(forPhone phone: String) async throws {
            phoneResetCodes = phoneResetCodes.filter { !$0.key.hasPrefix("\(phone):") }
        }

        public func incrementFailedAttempts(for code: any PhonePasswordResetCode) async throws {
            let key = "\(code.phone):\(code.codeHash)"
            phoneResetCodes[key]?.failedAttempts += 1
        }
    }
}

// MARK: - InMemoryMagicLinkTokenStore

public extension Passage.OnlyForTest.InMemoryStore {

    final class InMemoryMagicLinkTokenStore: Passage.MagicLinkTokenStore, @unchecked Sendable {

        private var emailMagicLinks: [String: Passage.OnlyForTest.InMemoryMagicLinkToken] = [:]

        // MARK: Email Magic Links

        @discardableResult
        public func createEmailMagicLink(
            for user: (any User)?,
            identifier: Identifier,
            tokenHash: String,
            sessionTokenHash: String?,
            expiresAt: Date
        ) async throws -> any MagicLinkToken {
            let code = Passage.OnlyForTest.InMemoryMagicLinkToken(
                userId: user?.id?.description,
                identifier: identifier,
                tokenHash: tokenHash,
                sessionTokenHash: sessionTokenHash,
                expiresAt: expiresAt,
                failedAttempts: 0
            )
            emailMagicLinks[tokenHash] = code
            return code
        }

        public func findEmailMagicLink(tokenHash: String) async throws -> (any MagicLinkToken)? {
            return emailMagicLinks[tokenHash]
        }

        public func invalidateEmailMagicLinks(for identifier: Identifier) async throws {
            emailMagicLinks = emailMagicLinks.filter { $0.value.identifier != identifier }
        }

        public func incrementFailedAttempts(for magicLink: any MagicLinkToken) async throws {
            emailMagicLinks[magicLink.tokenHash]?.failedAttempts += 1
        }
    }

}

// MARK: - InMemoryExchangeTokenStore

public extension Passage.OnlyForTest.InMemoryStore {

    final class InMemoryExchangeTokenStore: Passage.ExchangeTokenStore, @unchecked Sendable {

        private var tokens: [String: Passage.OnlyForTest.InMemoryExchangeToken] = [:]

        @discardableResult
        public func createExchangeToken(
            for user: any User,
            tokenHash: String,
            expiresAt: Date
        ) async throws -> any ExchangeToken {
            guard let userId = user.id?.description else {
                throw PassageError.unexpected(message: "User ID is missing")
            }

            let tokenId = UUID().uuidString
            let inMemoryUser = Passage.OnlyForTest.InMemoryUser(
                id: userId,
                email: user.email,
                phone: user.phone,
                username: user.username,
                passwordHash: user.passwordHash,
                isAnonymous: user.isAnonymous,
                isEmailVerified: user.isEmailVerified,
                isPhoneVerified: user.isPhoneVerified
            )
            let token = Passage.OnlyForTest.InMemoryExchangeToken(
                id: tokenId,
                user: inMemoryUser,
                tokenHash: tokenHash,
                expiresAt: expiresAt,
                consumedAt: nil,
                createdAt: Date()
            )
            tokens[tokenHash] = token
            return token
        }

        public func find(exchangeTokenHash hash: String) async throws -> (any ExchangeToken)? {
            return tokens[hash]
        }

        public func consume(exchangeToken: any ExchangeToken) async throws {
            tokens[exchangeToken.tokenHash]?.consumedAt = Date()
        }

        public func cleanupExpiredTokens(before date: Date) async throws {
            tokens = tokens.filter { $0.value.expiresAt >= date }
        }
    }

}

// MARK: - InMemoryPasskeyCredentialStore

public extension Passage.OnlyForTest.InMemoryStore {

    final class InMemoryPasskeyCredentialStore: Passage.PasskeyCredentialStore, @unchecked Sendable {

        private var credentials: [String: Passage.OnlyForTest.InMemoryStoredPasskey] = [:]

        public init() {}

        @discardableResult
        public func createPasskeyCredential(
            for user: any User,
            from credential: PasskeyCredential
        ) async throws -> any StoredPasskeyCredential {
            guard let userId = user.id?.description else {
                throw PassageError.unexpected(message: "User ID is missing")
            }
            let inMemoryUser = Passage.OnlyForTest.InMemoryUser(
                id: userId,
                email: user.email,
                phone: user.phone,
                username: user.username,
                passwordHash: user.passwordHash,
                isAnonymous: user.isAnonymous,
                isEmailVerified: user.isEmailVerified,
                isPhoneVerified: user.isPhoneVerified
            )
            let now = Date()
            let stored = Passage.OnlyForTest.InMemoryStoredPasskey(
                id: UUID().uuidString,
                user: inMemoryUser,
                credentialID: credential.credentialID,
                publicKey: credential.publicKey,
                signCount: credential.signCount,
                uvInitialized: credential.uvInitialized,
                transports: credential.transports,
                backupEligible: credential.backupEligible,
                isBackedUp: credential.isBackedUp,
                aaguid: credential.aaguid,
                attestationFormat: credential.attestationFormat,
                createdAt: now,
                updatedAt: now
            )
            credentials[credential.credentialID] = stored
            return stored
        }

        public func find(byCredentialID credentialID: String) async throws -> (any StoredPasskeyCredential)? {
            credentials[credentialID]
        }

        public func listPasskeyCredentials(forUser user: any User) async throws -> [any StoredPasskeyCredential] {
            guard let userId = user.id?.description else { return [] }
            return credentials.values.filter { $0.user.id == userId }
        }

        public func updatePasskeyCredentialAfterAuthentication(
            forCredentialID credentialID: String,
            newSignCount: UInt32,
            isBackedUp: Bool
        ) async throws {
            credentials[credentialID]?.signCount = newSignCount
            credentials[credentialID]?.isBackedUp = isBackedUp
            credentials[credentialID]?.updatedAt = Date()
        }

        public func deletePasskeyCredential(byCredentialID credentialID: String) async throws {
            credentials.removeValue(forKey: credentialID)
        }
    }

}

// MARK: - InMemoryPasskeyChallengeStore

public extension Passage.OnlyForTest.InMemoryStore {

    final class InMemoryPasskeyChallengeStore: Passage.PasskeyChallengeStore, @unchecked Sendable {

        private var challenges: [String: Passage.OnlyForTest.InMemoryStoredPasskeyChallenge] = [:]

        public init() {}

        @discardableResult
        public func createPasskeyChallenge(
            for user: (any User)?,
            from challenge: PasskeyChallenge
        ) async throws -> any StoredPasskeyChallenge {
            let inMemoryUser: Passage.OnlyForTest.InMemoryUser? = user.map { u in
                Passage.OnlyForTest.InMemoryUser(
                    id: u.id?.description ?? "",
                    email: u.email,
                    phone: u.phone,
                    username: u.username,
                    passwordHash: u.passwordHash,
                    isAnonymous: u.isAnonymous,
                    isEmailVerified: u.isEmailVerified,
                    isPhoneVerified: u.isPhoneVerified
                )
            }
            let hash = challenge.bytes.sha256Hex
            let stored = Passage.OnlyForTest.InMemoryStoredPasskeyChallenge(
                id: UUID().uuidString,
                user: inMemoryUser,
                kind: challenge.kind,
                challengeHash: hash,
                expiresAt: challenge.expiresAt,
                consumedAt: nil,
                createdAt: Date()
            )
            challenges[hash] = stored
            return stored
        }

        public func find(passkeyChallengeMatching bytes: Data) async throws -> (any StoredPasskeyChallenge)? {
            challenges[bytes.sha256Hex]
        }

        public func consume(passkeyChallenge: any StoredPasskeyChallenge) async throws {
            challenges[passkeyChallenge.challengeHash]?.consumedAt = Date()
        }

        public func cleanupExpiredPasskeyChallenges(before date: Date) async throws {
            challenges = challenges.filter { $0.value.expiresAt >= date }
        }
    }

}

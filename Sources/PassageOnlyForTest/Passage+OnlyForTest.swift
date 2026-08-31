public import Passage

public extension Passage {

    enum OnlyForTest {

        public struct InMemoryStore: Store, Sendable {
            public let users: any Passage.UserStore
            public let tokens: any Passage.TokenStore
            public let verificationCodes: any Passage.VerificationCodeStore
            public let restorationCodes: any Passage.RestorationCodeStore
            public let magicLinkTokens: any Passage.MagicLinkTokenStore
            public let exchangeTokens: any Passage.ExchangeTokenStore
            public let passkeyCredentials: (any Passage.PasskeyCredentialStore)?
            public let passkeyChallenges: (any Passage.PasskeyChallengeStore)?

            public init() {
                self.users = InMemoryUserStore()
                self.tokens = InMemoryTokenStore()
                self.verificationCodes = InMemoryVerificationStore()
                self.restorationCodes = InMemoryRestorationStore()
                self.magicLinkTokens = InMemoryMagicLinkTokenStore()
                self.exchangeTokens = InMemoryExchangeTokenStore()
                self.passkeyCredentials = InMemoryPasskeyCredentialStore()
                self.passkeyChallenges = InMemoryPasskeyChallengeStore()
            }

            public func transaction<T: Sendable>(
                _ body: @escaping @Sendable (any Passage.Store) async throws -> T
            ) async throws -> T {
                guard let tokens = tokens as? InMemoryTokenStore else {
                    return try await body(self)
                }
                let snapshot = tokens.snapshot()
                do {
                    return try await body(self)
                } catch {
                    tokens.restore(snapshot)
                    throw error
                }
            }
        }

    }

}


// 

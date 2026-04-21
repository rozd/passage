public import Passage
public import Vapor

// MARK: - OnlyForTest Federated Login Mock

public extension Passage.OnlyForTest {

    struct MockFederatedLoginService: Passage.FederatedLoginService {

        public init() {
        }

        public func register(
            router: any RoutesBuilder,
            origin: URL,
            group: [PathComponent],
            config: Passage.Configuration.FederatedLogin,
            onSignIn: @escaping @Sendable (
                _ request: Request,
                _ identity: FederatedIdentity,
            ) async throws -> some AsyncResponseEncodable
        ) throws {

        }
    }

}

public import Vapor

public extension Passage {

    protocol FederatedLoginService: Sendable {

        func register(
            router: any RoutesBuilder,
            origin: URL,
            group: [PathComponent],
            config: Passage.Configuration.FederatedLogin,
            onSignIn: @escaping @Sendable (
                _ request: Request,
                _ identity: FederatedIdentity,
            ) async throws -> some AsyncResponseEncodable
        ) throws
    }

}

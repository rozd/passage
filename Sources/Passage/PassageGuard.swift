public import Vapor

public struct PassageGuard: AsyncMiddleware {

    let error: (any Error)?

    public init(
        throwing error: (any Error)? = nil
    ) {
        self.error = error
    }

    public func respond(
        to request: Request,
        chainingTo next: any AsyncResponder,
    ) async throws -> Response {
        guard request.passage.hasUser else {
            throw error ?? Abort(.unauthorized,
                                 reason: "User not authenticated.",
                                 suggestedFixes: [
                                    "Ensure the request includes valid authentication credentials."
                                 ]
            )
        }
        return try await next.respond(to: request)
    }

}

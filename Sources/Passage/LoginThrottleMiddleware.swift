import Foundation
import Vapor

// MARK: - Login Throttle Middleware

struct LoginThrottleMiddleware: AsyncMiddleware {

    func respond(
        to request: Request,
        chainingTo next: any AsyncResponder
    ) async throws -> Response {
        let rules = request.configuration.throttle.login
        guard rules.enabled else {
            return try await next.respond(to: request)
        }

        let source = request.remoteAddress?.ipAddress ?? "unknown"
        let bucket = Passage.Throttle.Bucket(
            scope: .login,
            dimension: .source(source),
            enabled: rules.enabled,
        )
        let now = Date()

        if case let .throttled(delay) = await request.throttle.check(
            bucket: bucket, against: rules.perSource, at: now
        ) {
            throw AuthenticationError.tooManyLoginAttempts(retryAfter: delay)
        }

        do {
            let response = try await next.respond(to: request)
            let code = Int(response.status.code)
            if (200..<300).contains(code) {
                await request.throttle.reset(bucket: bucket)
            } else if code >= 400 {
                await request.throttle.penalize(bucket: bucket, at: now)
            }
            return response
        } catch {
            await request.throttle.penalize(bucket: bucket, at: now)
            throw error
        }
    }
}

public import Foundation
public import JWT

public struct AccessToken: Sendable {

    // Standard claims
    let subject: SubjectClaim
    let expiration: ExpirationClaim
    let issuedAt: IssuedAtClaim
    let issuer: IssuerClaim?
    let audience: AudienceClaim?

    // Session claim
    public let sessionId: UUID

    // Authorization claims
    let scope: String?

    init(
        userId: String,
        issuedAt: Date = .now,
        expiresAt: Date,
        issuer: String?,
        audience: String?,
        scope: String?,
        sessionId: UUID
    ) {
        self.subject = SubjectClaim(value: userId)
        self.issuedAt = IssuedAtClaim(value: issuedAt)
        self.expiration = ExpirationClaim(value: expiresAt)
        self.issuer = issuer.map { IssuerClaim(value: $0) }
        self.audience = audience.map { AudienceClaim(value: $0) }
        self.scope = scope
        self.sessionId = sessionId
    }
}

// MARK: - JWTPayload

extension AccessToken: JWTPayload {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case issuedAt = "iat"
        case issuer = "iss"
        case audience = "aud"
        case sessionId = "sid"
        case scope
    }

    public func verify(using algorithm: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
    }
}

import Foundation
import JWT
@testable import Passage
import Testing

@Suite("ID Token Tests")
struct IdTokenTests {

    // MARK: - Structure Tests

    @Test("ID token initialization with all properties")
    func initializationWithAllProperties() {
        let subject = SubjectClaim(value: "user123")
        let expiration = ExpirationClaim(value: Date(timeIntervalSinceNow: 3600))
        let issuedAt = IssuedAtClaim(value: Date())
        let issuer = IssuerClaim(value: "https://example.com")
        let audience = AudienceClaim(value: ["api.example.com"])
        let email = "test@example.com"
        let phone = "+1234567890"

        let token = IdToken(
            subject: subject,
            expiration: expiration,
            issuedAt: issuedAt,
            issuer: issuer,
            audience: audience,
            email: email,
            phone: phone
        )

        #expect(token.subject.value == "user123")
        #expect(token.email == "test@example.com")
        #expect(token.phone == "+1234567890")
        #expect(token.issuer?.value == "https://example.com")
        #expect(token.audience?.value.first == "api.example.com")
    }

    @Test("ID token with optional email and phone", arguments: [
        ("test@example.com", nil),
        (nil, "+1234567890"),
        (nil, nil)
    ])
    func optionalEmailAndPhone(email: String?, phone: String?) {
        let subject = SubjectClaim(value: "user123")
        let expiration = ExpirationClaim(value: Date(timeIntervalSinceNow: 3600))
        let issuedAt = IssuedAtClaim(value: Date())

        let token = IdToken(
            subject: subject,
            expiration: expiration,
            issuedAt: issuedAt,
            issuer: nil,
            audience: nil,
            email: email,
            phone: phone
        )

        #expect(token.email == email)
        #expect(token.phone == phone)
    }

    // MARK: - UserInfo Protocol Conformance Tests

    @Test("ID token conforms to UserInfo")
    func conformsToUserInfo() {
        let subject = SubjectClaim(value: "user123")
        let expiration = ExpirationClaim(value: Date(timeIntervalSinceNow: 3600))
        let issuedAt = IssuedAtClaim(value: Date())

        let token = IdToken(
            subject: subject,
            expiration: expiration,
            issuedAt: issuedAt,
            issuer: nil,
            audience: nil,
            email: "test@example.com",
            phone: "+1234567890"
        )

        // Verify IdToken conforms to UserInfo protocol
        let userInfo: any UserInfo = token

        #expect(userInfo.email == "test@example.com")
        #expect(userInfo.phone == "+1234567890")
    }

    @Test("ID token UserInfo with nil values")
    func userInfoWithNilValues() {
        let subject = SubjectClaim(value: "user123")
        let expiration = ExpirationClaim(value: Date(timeIntervalSinceNow: 3600))
        let issuedAt = IssuedAtClaim(value: Date())

        let token = IdToken(
            subject: subject,
            expiration: expiration,
            issuedAt: issuedAt,
            issuer: nil,
            audience: nil,
            email: nil,
            phone: nil
        )

        let userInfo: any UserInfo = token

        #expect(userInfo.email == nil)
        #expect(userInfo.phone == nil)
    }

    // MARK: - Claims Tests

    @Test("ID token subject claim", arguments: [
        "user123",
        "user-abc-123",
        "test-user-456"
    ])
    func subjectClaim(userId: String) {
        let subject = SubjectClaim(value: userId)
        let expiration = ExpirationClaim(value: Date(timeIntervalSinceNow: 3600))
        let issuedAt = IssuedAtClaim(value: Date())

        let token = IdToken(
            subject: subject,
            expiration: expiration,
            issuedAt: issuedAt,
            issuer: nil,
            audience: nil,
            email: nil,
            phone: nil
        )

        #expect(token.subject.value == userId)
    }

    @Test("ID token expiration claim")
    func expirationClaim() {
        let expirationDate = Date(timeIntervalSinceNow: 7200)
        let subject = SubjectClaim(value: "user123")
        let expiration = ExpirationClaim(value: expirationDate)
        let issuedAt = IssuedAtClaim(value: Date())

        let token = IdToken(
            subject: subject,
            expiration: expiration,
            issuedAt: issuedAt,
            issuer: nil,
            audience: nil,
            email: nil,
            phone: nil
        )

        #expect(token.expiration.value.timeIntervalSince1970 == expirationDate.timeIntervalSince1970)
    }

    @Test("ID token issuedAt claim")
    func issuedAtClaim() {
        let issuedAtDate = Date(timeIntervalSinceNow: -100)
        let subject = SubjectClaim(value: "user123")
        let expiration = ExpirationClaim(value: Date(timeIntervalSinceNow: 3600))
        let issuedAt = IssuedAtClaim(value: issuedAtDate)

        let token = IdToken(
            subject: subject,
            expiration: expiration,
            issuedAt: issuedAt,
            issuer: nil,
            audience: nil,
            email: nil,
            phone: nil
        )

        #expect(token.issuedAt.value.timeIntervalSince1970 == issuedAtDate.timeIntervalSince1970)
    }

    @Test("ID token issuer claim", arguments: [
        "https://auth.example.com",
        "https://example.com",
        nil
    ])
    func issuerClaim(issuerValue: String?) {
        let subject = SubjectClaim(value: "user123")
        let expiration = ExpirationClaim(value: Date(timeIntervalSinceNow: 3600))
        let issuedAt = IssuedAtClaim(value: Date())
        let issuer = issuerValue.map { IssuerClaim(value: $0) }

        let token = IdToken(
            subject: subject,
            expiration: expiration,
            issuedAt: issuedAt,
            issuer: issuer,
            audience: nil,
            email: nil,
            phone: nil
        )

        #expect(token.issuer?.value == issuerValue)
    }

    @Test("ID token audience claim", arguments: [
        "api.example.com",
        "service.example.com",
        nil
    ])
    func audienceClaim(audienceValue: String?) {
        let subject = SubjectClaim(value: "user123")
        let expiration = ExpirationClaim(value: Date(timeIntervalSinceNow: 3600))
        let issuedAt = IssuedAtClaim(value: Date())
        let audience = audienceValue.map { AudienceClaim(value: [$0]) }

        let token = IdToken(
            subject: subject,
            expiration: expiration,
            issuedAt: issuedAt,
            issuer: nil,
            audience: audience,
            email: nil,
            phone: nil
        )

        #expect(token.audience?.value.first == audienceValue)
    }

    // MARK: - JWT Encoding/Decoding Tests

    @Test("ID token JWT encoding and decoding")
    func jwtEncodingDecoding() async throws {
        let keys = JWTKeyCollection()
        await keys.add(hmac: "secret-test-key-that-is-long-enough-for-hs256", digestAlgorithm: .sha256)

        let originalToken = IdToken(
            subject: SubjectClaim(value: "user123"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            issuer: IssuerClaim(value: "https://example.com"),
            audience: AudienceClaim(value: ["api.example.com"]),
            email: "test@example.com",
            phone: "+1234567890"
        )

        // Encode to JWT string
        let jwtString = try await keys.sign(originalToken)

        // Decode from JWT string
        let decodedToken = try await keys.verify(jwtString, as: IdToken.self)

        // Verify all properties match
        #expect(decodedToken.subject.value == originalToken.subject.value)
        #expect(decodedToken.email == originalToken.email)
        #expect(decodedToken.phone == originalToken.phone)
        #expect(decodedToken.issuer?.value == originalToken.issuer?.value)
        #expect(decodedToken.audience?.value.first == originalToken.audience?.value.first)
    }

    @Test("ID token JWT encoding with nil optional fields")
    func jwtEncodingWithNilFields() async throws {
        let keys = JWTKeyCollection()
        await keys.add(hmac: "secret-test-key-that-is-long-enough-for-hs256", digestAlgorithm: .sha256)

        let originalToken = IdToken(
            subject: SubjectClaim(value: "user123"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            issuer: nil,
            audience: nil,
            email: nil,
            phone: nil
        )

        let jwtString = try await keys.sign(originalToken)
        let decodedToken = try await keys.verify(jwtString, as: IdToken.self)

        #expect(decodedToken.subject.value == originalToken.subject.value)
        #expect(decodedToken.email == nil)
        #expect(decodedToken.phone == nil)
        #expect(decodedToken.issuer == nil)
        #expect(decodedToken.audience == nil)
    }

    // MARK: - JWT Verification Tests

    @Test("ID token expiration verification succeeds for valid token")
    func expirationVerificationSucceeds() {
        let token = IdToken(
            subject: SubjectClaim(value: "user123"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            issuer: nil,
            audience: nil,
            email: nil,
            phone: nil
        )

        // ExpirationClaim should verify successfully for future dates
        #expect(throws: Never.self) {
            try token.expiration.verifyNotExpired()
        }
    }

    @Test("ID token expiration verification fails for expired token")
    func expirationVerificationFails() {
        let expiredToken = IdToken(
            subject: SubjectClaim(value: "user123"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: -100)),
            issuedAt: IssuedAtClaim(value: Date(timeIntervalSinceNow: -200)),
            issuer: nil,
            audience: nil,
            email: nil,
            phone: nil
        )

        // ExpirationClaim should throw for past dates
        #expect(throws: (any Error).self) {
            try expiredToken.expiration.verifyNotExpired()
        }
    }

    @Test("ID token round-trip with verification")
    func roundTripWithVerification() async throws {
        let keys = JWTKeyCollection()
        await keys.add(hmac: "secret-test-key-that-is-long-enough-for-hs256", digestAlgorithm: .sha256)

        let originalToken = IdToken(
            subject: SubjectClaim(value: "user123"),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 3600)),
            issuedAt: IssuedAtClaim(value: Date()),
            issuer: IssuerClaim(value: "https://example.com"),
            audience: AudienceClaim(value: ["api.example.com"]),
            email: "test@example.com",
            phone: "+1234567890"
        )

        // Sign token
        let jwtString = try await keys.sign(originalToken)

        // Verify and decode (verify() automatically checks expiration)
        let decodedToken = try await keys.verify(jwtString, as: IdToken.self)

        // All properties should match
        #expect(decodedToken.subject.value == "user123")
        #expect(decodedToken.email == "test@example.com")
        #expect(decodedToken.phone == "+1234567890")
    }

}

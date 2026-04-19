import Testing
import Vapor
@testable import Passage

@Suite("Authentication Error Tests")
struct AuthenticationErrorTests {

    // MARK: - HTTP Status Code Tests

    @Test("Registration error status codes", arguments: [
        (AuthenticationError.identifierNotSpecified, HTTPResponseStatus.badRequest),
        (AuthenticationError.emailAlreadyRegistered, HTTPResponseStatus.conflict),
        (AuthenticationError.phoneAlreadyRegistered, HTTPResponseStatus.conflict),
        (AuthenticationError.usernameAlreadyRegistered, HTTPResponseStatus.conflict),
        (AuthenticationError.passwordsDoNotMatch, HTTPResponseStatus.badRequest)
    ])
    func registrationErrorStatusCodes(error: AuthenticationError, expectedStatus: HTTPResponseStatus) {
        #expect(error.status == expectedStatus)
    }

    @Test("Login error status codes", arguments: [
        (AuthenticationError.invalidEmailOrPassword, HTTPResponseStatus.unauthorized),
        (AuthenticationError.invalidPhoneOrPassword, HTTPResponseStatus.unauthorized),
        (AuthenticationError.invalidUsernameOrPassword, HTTPResponseStatus.unauthorized),
        (AuthenticationError.emailIsNotVerified, HTTPResponseStatus.forbidden),
        (AuthenticationError.phoneIsNotVerified, HTTPResponseStatus.forbidden),
        (AuthenticationError.passwordIsNotSet, HTTPResponseStatus.internalServerError)
    ])
    func loginErrorStatusCodes(error: AuthenticationError, expectedStatus: HTTPResponseStatus) {
        #expect(error.status == expectedStatus)
    }

    @Test("Token error status codes", arguments: [
        (AuthenticationError.invalidRefreshToken, HTTPResponseStatus.unauthorized),
        (AuthenticationError.refreshTokenExpired, HTTPResponseStatus.unauthorized),
        (AuthenticationError.refreshTokenNotFound, HTTPResponseStatus.notFound)
    ])
    func tokenErrorStatusCodes(error: AuthenticationError, expectedStatus: HTTPResponseStatus) {
        #expect(error.status == expectedStatus)
    }

    @Test("User error status codes")
    func userErrorStatusCodes() {
        let error = AuthenticationError.userNotFound
        #expect(error.status == .notFound)
    }

    @Test("Email verification error status codes", arguments: [
        (AuthenticationError.emailNotSet, HTTPResponseStatus.badRequest),
        (AuthenticationError.emailAlreadyVerified, HTTPResponseStatus.conflict)
    ])
    func emailVerificationErrorStatusCodes(error: AuthenticationError, expectedStatus: HTTPResponseStatus) {
        #expect(error.status == expectedStatus)
    }

    @Test("Phone verification error status codes", arguments: [
        (AuthenticationError.phoneNotSet, HTTPResponseStatus.badRequest),
        (AuthenticationError.phoneAlreadyVerified, HTTPResponseStatus.conflict)
    ])
    func phoneVerificationErrorStatusCodes(error: AuthenticationError, expectedStatus: HTTPResponseStatus) {
        #expect(error.status == expectedStatus)
    }

    @Test("Shared verification error status codes", arguments: [
        (AuthenticationError.invalidVerificationCode, HTTPResponseStatus.unauthorized),
        (AuthenticationError.verificationCodeExpiredOrMaxAttempts, HTTPResponseStatus.gone)
    ])
    func sharedVerificationErrorStatusCodes(error: AuthenticationError, expectedStatus: HTTPResponseStatus) {
        #expect(error.status == expectedStatus)
    }

    @Test("Restoration error status codes", arguments: [
        (AuthenticationError.restorationCodeInvalid, HTTPResponseStatus.unauthorized),
        (AuthenticationError.restorationCodeExpired, HTTPResponseStatus.gone),
        (AuthenticationError.restorationCodeMaxAttempts, HTTPResponseStatus.gone),
        (AuthenticationError.restorationIdentifierNotFound, HTTPResponseStatus.notFound),
        (AuthenticationError.restorationDeliveryNotAvailable, HTTPResponseStatus.serviceUnavailable)
    ])
    func restorationErrorStatusCodes(error: AuthenticationError, expectedStatus: HTTPResponseStatus) {
        #expect(error.status == expectedStatus)
    }

    @Test("Passkey error status codes", arguments: [
        (AuthenticationError.invalidPasskeyChallenge, HTTPResponseStatus.unauthorized),
        (AuthenticationError.unknownPasskey, HTTPResponseStatus.unauthorized),
        (AuthenticationError.discoverableLoginDisabled, HTTPResponseStatus.badRequest)
    ])
    func passkeyErrorStatusCodes(error: AuthenticationError, expectedStatus: HTTPResponseStatus) {
        #expect(error.status == expectedStatus)
    }

    // MARK: - Error Reason Tests

    @Test("Registration error reasons", arguments: [
        (AuthenticationError.identifierNotSpecified, "No identifier (email, phone, or username) was specified."),
        (AuthenticationError.emailAlreadyRegistered, "This email is already registered."),
        (AuthenticationError.phoneAlreadyRegistered, "This phone number is already registered."),
        (AuthenticationError.usernameAlreadyRegistered, "This username is already taken."),
        (AuthenticationError.passwordsDoNotMatch, "The passwords do not match.")
    ])
    func registrationErrorReasons(error: AuthenticationError, expectedReason: String) {
        #expect(error.reason == expectedReason)
    }

    @Test("Login error reasons", arguments: [
        (AuthenticationError.invalidEmailOrPassword, "Invalid email or password."),
        (AuthenticationError.invalidPhoneOrPassword, "Invalid phone or password."),
        (AuthenticationError.invalidUsernameOrPassword, "Invalid username or password."),
        (AuthenticationError.emailIsNotVerified, "Email address is not verified."),
        (AuthenticationError.phoneIsNotVerified, "Phone number is not verified."),
        (AuthenticationError.passwordIsNotSet, "Password is not set for this account.")
    ])
    func loginErrorReasons(error: AuthenticationError, expectedReason: String) {
        #expect(error.reason == expectedReason)
    }

    @Test("Token error reasons", arguments: [
        (AuthenticationError.invalidRefreshToken, "The refresh token is invalid."),
        (AuthenticationError.refreshTokenExpired, "The refresh token has expired."),
        (AuthenticationError.refreshTokenNotFound, "Refresh token not found.")
    ])
    func tokenErrorReasons(error: AuthenticationError, expectedReason: String) {
        #expect(error.reason == expectedReason)
    }

    @Test("User error reason")
    func userErrorReason() {
        let error = AuthenticationError.userNotFound
        #expect(error.reason == "User not found.")
    }

    @Test("Email verification error reasons", arguments: [
        (AuthenticationError.emailNotSet, "Email address is not set for this account."),
        (AuthenticationError.emailAlreadyVerified, "Email address is already verified.")
    ])
    func emailVerificationErrorReasons(error: AuthenticationError, expectedReason: String) {
        #expect(error.reason == expectedReason)
    }

    @Test("Phone verification error reasons", arguments: [
        (AuthenticationError.phoneNotSet, "Phone number is not set for this account."),
        (AuthenticationError.phoneAlreadyVerified, "Phone number is already verified.")
    ])
    func phoneVerificationErrorReasons(error: AuthenticationError, expectedReason: String) {
        #expect(error.reason == expectedReason)
    }

    @Test("Shared verification error reasons", arguments: [
        (AuthenticationError.invalidVerificationCode, "Invalid verification code."),
        (AuthenticationError.verificationCodeExpiredOrMaxAttempts, "Verification code has expired or maximum attempts exceeded.")
    ])
    func sharedVerificationErrorReasons(error: AuthenticationError, expectedReason: String) {
        #expect(error.reason == expectedReason)
    }

    @Test("Restoration error reasons", arguments: [
        (AuthenticationError.restorationCodeInvalid, "Invalid password reset code."),
        (AuthenticationError.restorationCodeExpired, "Password reset code has expired."),
        (AuthenticationError.restorationCodeMaxAttempts, "Maximum password reset attempts exceeded."),
        (AuthenticationError.restorationIdentifierNotFound, "No account found with this identifier."),
        (AuthenticationError.restorationDeliveryNotAvailable, "Password reset delivery is not available for this identifier type.")
    ])
    func restorationErrorReasons(error: AuthenticationError, expectedReason: String) {
        #expect(error.reason == expectedReason)
    }

    @Test("Passkey error reasons", arguments: [
        (AuthenticationError.invalidPasskeyChallenge, "Invalid or expired passkey challenge."),
        (AuthenticationError.unknownPasskey, "Passkey is not registered."),
        (AuthenticationError.discoverableLoginDisabled, "Discoverable passkey login is disabled by server policy.")
    ])
    func passkeyErrorReasons(error: AuthenticationError, expectedReason: String) {
        #expect(error.reason == expectedReason)
    }

    // MARK: - Error Protocol Conformance Tests

    @Test("AuthenticationError conforms to Error protocol")
    func errorProtocolConformance() {
        let error: any Error = AuthenticationError.invalidEmailOrPassword
        #expect(error is AuthenticationError)
    }

    @Test("AuthenticationError conforms to AbortError protocol")
    func abortErrorConformance() {
        let error: any AbortError = AuthenticationError.invalidEmailOrPassword
        #expect(error.status == .unauthorized)
        #expect(!error.reason.isEmpty)
    }

    // MARK: - Error Categorization Tests

    @Test("Registration errors use appropriate HTTP status codes")
    func registrationErrorsUseAppropriateStatusCodes() {
        // Validation errors should be 400 Bad Request
        #expect(AuthenticationError.identifierNotSpecified.status == .badRequest)
        #expect(AuthenticationError.passwordsDoNotMatch.status == .badRequest)

        // Conflict errors should be 409 Conflict
        #expect(AuthenticationError.emailAlreadyRegistered.status == .conflict)
        #expect(AuthenticationError.phoneAlreadyRegistered.status == .conflict)
        #expect(AuthenticationError.usernameAlreadyRegistered.status == .conflict)
    }

    @Test("Login errors use appropriate HTTP status codes")
    func loginErrorsUseAppropriateStatusCodes() {
        // Invalid credentials should be 401 Unauthorized
        #expect(AuthenticationError.invalidEmailOrPassword.status == .unauthorized)
        #expect(AuthenticationError.invalidPhoneOrPassword.status == .unauthorized)
        #expect(AuthenticationError.invalidUsernameOrPassword.status == .unauthorized)

        // Verification required should be 403 Forbidden
        #expect(AuthenticationError.emailIsNotVerified.status == .forbidden)
        #expect(AuthenticationError.phoneIsNotVerified.status == .forbidden)
    }

    @Test("Token errors use appropriate HTTP status codes")
    func tokenErrorsUseAppropriateStatusCodes() {
        // Invalid/expired tokens should be 401 Unauthorized
        #expect(AuthenticationError.invalidRefreshToken.status == .unauthorized)
        #expect(AuthenticationError.refreshTokenExpired.status == .unauthorized)

        // Missing token should be 404 Not Found
        #expect(AuthenticationError.refreshTokenNotFound.status == .notFound)
    }

    @Test("Verification errors use appropriate HTTP status codes")
    func verificationErrorsUseAppropriateStatusCodes() {
        // Invalid code should be 401 Unauthorized
        #expect(AuthenticationError.invalidVerificationCode.status == .unauthorized)

        // Expired/max attempts should be 410 Gone
        #expect(AuthenticationError.verificationCodeExpiredOrMaxAttempts.status == .gone)
    }

    @Test("Restoration errors use appropriate HTTP status codes")
    func restorationErrorsUseAppropriateStatusCodes() {
        // Invalid code should be 401 Unauthorized
        #expect(AuthenticationError.restorationCodeInvalid.status == .unauthorized)

        // Expired/max attempts should be 410 Gone
        #expect(AuthenticationError.restorationCodeExpired.status == .gone)
        #expect(AuthenticationError.restorationCodeMaxAttempts.status == .gone)

        // Not found should be 404
        #expect(AuthenticationError.restorationIdentifierNotFound.status == .notFound)

        // Service issues should be 503 Service Unavailable
        #expect(AuthenticationError.restorationDeliveryNotAvailable.status == .serviceUnavailable)
    }

    // MARK: - Error Message Quality Tests

    @Test("All error reasons are non-empty")
    func allErrorReasonsAreNonEmpty() {
        let allErrors: [AuthenticationError] = [
            .identifierNotSpecified,
            .emailAlreadyRegistered,
            .phoneAlreadyRegistered,
            .usernameAlreadyRegistered,
            .passwordsDoNotMatch,
            .invalidEmailOrPassword,
            .invalidPhoneOrPassword,
            .invalidUsernameOrPassword,
            .emailIsNotVerified,
            .phoneIsNotVerified,
            .passwordIsNotSet,
            .invalidRefreshToken,
            .refreshTokenExpired,
            .refreshTokenNotFound,
            .userNotFound,
            .emailNotSet,
            .emailAlreadyVerified,
            .phoneNotSet,
            .phoneAlreadyVerified,
            .invalidVerificationCode,
            .verificationCodeExpiredOrMaxAttempts,
            .restorationCodeInvalid,
            .restorationCodeExpired,
            .restorationCodeMaxAttempts,
            .restorationIdentifierNotFound,
            .restorationDeliveryNotAvailable,
            .invalidPasskeyChallenge,
            .unknownPasskey,
            .discoverableLoginDisabled
        ]

        for error in allErrors {
            #expect(!error.reason.isEmpty)
        }
    }

    @Test("Error reasons end with proper punctuation")
    func errorReasonsEndWithProperPunctuation() {
        let allErrors: [AuthenticationError] = [
            .identifierNotSpecified,
            .emailAlreadyRegistered,
            .phoneAlreadyRegistered,
            .usernameAlreadyRegistered,
            .passwordsDoNotMatch,
            .invalidEmailOrPassword,
            .invalidPhoneOrPassword,
            .invalidUsernameOrPassword,
            .emailIsNotVerified,
            .phoneIsNotVerified,
            .passwordIsNotSet,
            .invalidRefreshToken,
            .refreshTokenExpired,
            .refreshTokenNotFound,
            .userNotFound,
            .emailNotSet,
            .emailAlreadyVerified,
            .phoneNotSet,
            .phoneAlreadyVerified,
            .invalidVerificationCode,
            .verificationCodeExpiredOrMaxAttempts,
            .restorationCodeInvalid,
            .restorationCodeExpired,
            .restorationCodeMaxAttempts,
            .restorationIdentifierNotFound,
            .restorationDeliveryNotAvailable,
            .invalidPasskeyChallenge,
            .unknownPasskey,
            .discoverableLoginDisabled
        ]

        for error in allErrors {
            #expect(error.reason.hasSuffix("."))
        }
    }

    // MARK: - Sendable Conformance Tests

    /// Helper function that requires Sendable conformance.
    /// If the type doesn't conform to Sendable, passing it to this function
    /// will cause a compile-time error.
    private func assertSendable<T: Sendable>(_ value: T) {}

    @Test("AuthenticationError conforms to Sendable")
    func conformsToSendable() {
        assertSendable(AuthenticationError.invalidEmailOrPassword)
        assertSendable(AuthenticationError.userNotFound)
        assertSendable(AuthenticationError.emailAlreadyRegistered)
    }
}

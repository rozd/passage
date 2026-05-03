public import Vapor

public enum AuthenticationError: Error, Equatable {
    // Registration errors
    case identifierNotSpecified
    case identifierAlreadyRegistered
    case emailAlreadyRegistered
    case phoneAlreadyRegistered
    case usernameAlreadyRegistered
    case passwordsDoNotMatch

    // Login errors
    case invalidEmailOrPassword
    case invalidPhoneOrPassword
    case invalidUsernameOrPassword
    case emailIsNotVerified
    case phoneIsNotVerified
    case passwordIsNotSet

    // Token errors
    case invalidRefreshToken
    case refreshTokenExpired
    case refreshTokenNotFound

    // User errors
    case userNotFound

    // Email verification errors
    case emailNotSet
    case emailAlreadyVerified

    // Phone verification errors
    case phoneNotSet
    case phoneAlreadyVerified

    // Shared verification errors
    case invalidVerificationCode
    case verificationCodeExpiredOrMaxAttempts

    // Restoration (password reset) errors
    case restorationCodeInvalid
    case restorationCodeExpired
    case restorationCodeMaxAttempts
    case restorationIdentifierNotFound
    case restorationDeliveryNotAvailable

    // Magic link (passwordless) errors
    case magicLinkInvalid
    case magicLinkExpired
    case magicLinkMaxAttempts
    case magicLinkEmailNotFound
    case magicLinkDifferentBrowser

    // Federated account errors
    case federatedAccountAlreadyLinked
    case federatedLoginFailed

    // Passkey errors
    case invalidPasskeyChallenge
    case unknownPasskey
    case discoverableLoginDisabled

    case tooManyLoginAttempts(retryAfter: TimeInterval)
}

extension AuthenticationError: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .identifierNotSpecified, .passwordsDoNotMatch:
            return .badRequest
        case .identifierAlreadyRegistered, .emailAlreadyRegistered, .phoneAlreadyRegistered, .usernameAlreadyRegistered:
            return .conflict
        case .invalidEmailOrPassword, .invalidPhoneOrPassword, .invalidUsernameOrPassword:
            return .unauthorized
        case .emailIsNotVerified, .phoneIsNotVerified:
            return .forbidden
        case .passwordIsNotSet:
            return .internalServerError
        case .invalidRefreshToken, .refreshTokenExpired:
            return .unauthorized
        case .refreshTokenNotFound, .userNotFound:
            return .notFound
        case .emailNotSet, .phoneNotSet:
            return .badRequest
        case .emailAlreadyVerified, .phoneAlreadyVerified:
            return .conflict
        case .invalidVerificationCode:
            return .unauthorized
        case .verificationCodeExpiredOrMaxAttempts:
            return .gone
        case .restorationCodeInvalid:
            return .unauthorized
        case .restorationCodeExpired, .restorationCodeMaxAttempts:
            return .gone
        case .restorationIdentifierNotFound:
            return .notFound
        case .restorationDeliveryNotAvailable:
            return .serviceUnavailable
        case .magicLinkInvalid:
            return .unauthorized
        case .magicLinkExpired, .magicLinkMaxAttempts:
            return .gone
        case .magicLinkEmailNotFound:
            return .notFound
        case .magicLinkDifferentBrowser:
            return .forbidden
        case .federatedAccountAlreadyLinked:
            return .conflict
        case .federatedLoginFailed:
            return .unauthorized
        case .invalidPasskeyChallenge:
            return .unauthorized
        case .unknownPasskey:
            return .unauthorized
        case .discoverableLoginDisabled:
            return .badRequest
        case .tooManyLoginAttempts:
            return .tooManyRequests
        }
    }

    public var reason: String {
        switch self {
        case .identifierNotSpecified:
            return "No identifier (email, phone, or username) was specified."
        case .identifierAlreadyRegistered:
            return "This identifier is already registered."
        case .emailAlreadyRegistered:
            return "This email is already registered."
        case .phoneAlreadyRegistered:
            return "This phone number is already registered."
        case .usernameAlreadyRegistered:
            return "This username is already taken."
        case .passwordsDoNotMatch:
            return "The passwords do not match."
        case .invalidEmailOrPassword:
            return "Invalid email or password."
        case .invalidPhoneOrPassword:
            return "Invalid phone or password."
        case .invalidUsernameOrPassword:
            return "Invalid username or password."
        case .emailIsNotVerified:
            return "Email address is not verified."
        case .phoneIsNotVerified:
            return "Phone number is not verified."
        case .passwordIsNotSet:
            return "Password is not set for this account."
        case .invalidRefreshToken:
            return "The refresh token is invalid."
        case .refreshTokenExpired:
            return "The refresh token has expired."
        case .refreshTokenNotFound:
            return "Refresh token not found."
        case .userNotFound:
            return "User not found."
        case .emailNotSet:
            return "Email address is not set for this account."
        case .emailAlreadyVerified:
            return "Email address is already verified."
        case .phoneNotSet:
            return "Phone number is not set for this account."
        case .phoneAlreadyVerified:
            return "Phone number is already verified."
        case .invalidVerificationCode:
            return "Invalid verification code."
        case .verificationCodeExpiredOrMaxAttempts:
            return "Verification code has expired or maximum attempts exceeded."
        case .restorationCodeInvalid:
            return "Invalid password reset code."
        case .restorationCodeExpired:
            return "Password reset code has expired."
        case .restorationCodeMaxAttempts:
            return "Maximum password reset attempts exceeded."
        case .restorationIdentifierNotFound:
            return "No account found with this identifier."
        case .restorationDeliveryNotAvailable:
            return "Password reset delivery is not available for this identifier type."
        case .magicLinkInvalid:
            return "Invalid magic link token."
        case .magicLinkExpired:
            return "Magic link has expired."
        case .magicLinkMaxAttempts:
            return "Maximum magic link verification attempts exceeded."
        case .magicLinkEmailNotFound:
            return "No account found with this email address and auto-creation is disabled."
        case .magicLinkDifferentBrowser:
            return "Magic link must be opened in the same browser where it was requested."
        case .federatedAccountAlreadyLinked:
            return "This federated account is already linked to another user."
        case .federatedLoginFailed:
            return "Federated login failed."
        case .invalidPasskeyChallenge:
            return "Invalid or expired passkey challenge."
        case .unknownPasskey:
            return "Passkey is not registered."
        case .discoverableLoginDisabled:
            return "Discoverable passkey login is disabled by server policy."
        case .tooManyLoginAttempts:
            return "Too many failed login attempts. Please try again later."
        }
    }

    public var headers: HTTPHeaders {
        switch self {
        case .tooManyLoginAttempts(let retryAfter):
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .retryAfter, value: String(Int(retryAfter.rounded(.up))))
            return headers
        default:
            return [:]
        }
    }
}

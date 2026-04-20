import Vapor

public enum PassageError: Error {
    case notConfigured
    case storeNotConfigured
    case jwksNotConfigured
    case emailDeliveryNotConfigured
    case phoneDeliveryNotConfigured
    case emailMagicLinkNotConfigured
    case passkeyNotConfigured
    case missingEnvironmentVariable(name: String)
    case unexpected(message: String)
    case passkeyServiceNotAvailable

    case passwordTooShort(minLength: Int)
    case passwordTooLong(maxLength: Int)
    case passwordRequiresUppercase
    case passwordRequiresLowercase
    case passwordRequiresDigit
    case passwordRequiresSpecialCharacter
    case passwordBreached
}

extension PassageError: AbortError {
    public var status: HTTPResponseStatus {
        switch self {
        case .notConfigured, .storeNotConfigured, .jwksNotConfigured, .emailDeliveryNotConfigured, .phoneDeliveryNotConfigured, .emailMagicLinkNotConfigured, .passkeyNotConfigured, .unexpected, .passkeyServiceNotAvailable:
            return .internalServerError
        case .missingEnvironmentVariable(name: _):
            return .internalServerError
        case .passwordTooShort(minLength: _), .passwordTooLong(maxLength: _), .passwordRequiresUppercase, .passwordRequiresLowercase, .passwordBreached, .passwordRequiresSpecialCharacter, .passwordRequiresDigit:
            return .badRequest
        }
    }

    public var reason: String {
        switch self {
        case .notConfigured:
            return "Passage is not configured. Call app.passage.configure() during application setup."
        case .storeNotConfigured:
            return "Passage store is not configured. Call app.passage.configure() during application setup."
        case .jwksNotConfigured:
            return "Passage JWKS is not configured. Call app.passage.configure() during application setup."
        case .emailDeliveryNotConfigured:
            return "Email delivery is not configured. Provide deliveryEmail in app.passage.configure()."
        case .phoneDeliveryNotConfigured:
            return "Phone delivery is not configured. Provide deliveryPhone in app.passage.configure()."
        case .emailMagicLinkNotConfigured:
            return "Email magic link is not configured. Provide emailMagicLink in passwordless configuration."
        case .passkeyNotConfigured:
            return "Passkey is not configured. Provide passkey in app.passage.configure()."
        case .unexpected(let message):
            return message
        case .missingEnvironmentVariable(name: let name):
            return "Missing environment variable: \(name)"
        case .passkeyServiceNotAvailable:
            return "Passkey service is not available. Please ensure you have integrated a passkey service implementation."
        case .passwordTooShort(minLength: let minLength):
            return "Password must be at least \(minLength) characters long."
        case .passwordTooLong(maxLength: let maxLength):
            return "Password must be no more than \(maxLength) characters long."
        case .passwordRequiresUppercase:
            return "Password must contain at least one uppercase letter."
        case .passwordRequiresDigit:
            return "Password must contain at least one digit."
        case .passwordRequiresLowercase:
            return "Password must contain at least one lowercase letter."
        case .passwordRequiresSpecialCharacter:
            return "Password must contain at least one special character."
        case .passwordBreached:
            return "Password has been previously used. Please try a different password."
        }
    }
}

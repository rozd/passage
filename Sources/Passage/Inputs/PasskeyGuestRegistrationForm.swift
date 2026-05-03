import Vapor

public protocol PasskeyGuestRegistrationForm: Form {
    var email: String? { get }
    var phone: String? { get }
    var username: String? { get }
    var displayName: String { get }

    func validate() throws
}

// MARK: - Identifier Conversion

extension PasskeyGuestRegistrationForm {

    func asIdentifier() throws -> Identifier {
        if let email = email {
            return .email(email)
        } else if let phone = phone {
            return .phone(phone)
        } else if let username = username {
            return .username(username)
        } else {
            throw AuthenticationError.identifierNotSpecified
        }
    }

}

import Vapor

// MARK: - Signup — Begin

public protocol PasskeySignupForm: Form {
    var email: String? { get }
    var phone: String? { get }
    var username: String? { get }
    var displayName: String { get }

    func validate() throws
}

extension PasskeySignupForm {

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

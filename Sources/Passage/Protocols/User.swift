public import Vapor

// MARK: - User

public protocol User: Authenticatable, SessionAuthenticatable, Sendable {
    associatedtype Id: CustomStringConvertible, Codable, Hashable, Equatable, Sendable

    var id: Id? { get }

    var email: String? { get }

    var phone: String? { get }

    var username: String? { get }

    var passwordHash: String? { get }

    var isAnonymous: Bool { get }

    var isEmailVerified: Bool { get }

    var isPhoneVerified: Bool { get }
}

extension User {

    func equals(to other: some User) -> Bool {
        do {
            return try self.requiredIdAsString == other.requiredIdAsString
        } catch {
            return false
        }
    }

}

// MARK: - Helpers

extension User {

    var requiredIdAsString: String {
        get throws {
            guard let id = id else {
                throw PassageError.unexpected(message: "User ID is missing")
            }
            return String(describing: id)
        }
    }

}

// MARK: - User Verification Check

extension User {

    /// Checks if the identifier is verified for the user.
    /// - Parameter identifier: The identifier to check.
    /// - Throws: An `AuthenticationError` if the identifier is not verified.
    func check(identifier: Identifier) throws {
        switch identifier.kind {
        case .email:
            guard isEmailVerified else {
                throw AuthenticationError.emailIsNotVerified
            }
        case .phone:
            guard isPhoneVerified else {
                throw AuthenticationError.phoneIsNotVerified
            }
        case .username:
            break
        case .federated:
            break
        }
    }
}

// MARK: - User Info

public protocol UserInfo: Sendable {

    var email: String? { get }

    var phone: String? { get }

}

public import Vapor

public struct AuthUser: Content {
    struct User: Content, UserInfo {
        let id: String
        let email: String?
        let phone: String?
    }

    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: TimeInterval
    let user: User
}

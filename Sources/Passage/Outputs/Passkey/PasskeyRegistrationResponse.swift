import Vapor

public struct PasskeyRegistrationResponse: Content {
    public let credentialID: String

    public init(credentialID: String) {
        self.credentialID = credentialID
    }
}

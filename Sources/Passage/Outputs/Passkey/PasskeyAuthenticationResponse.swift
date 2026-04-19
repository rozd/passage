import Vapor

public struct PasskeyAuthenticationResponse: Content {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}

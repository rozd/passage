import Vapor

extension Session {

    static let sessionIdKey = "_PassageSessionId"

    var sessionId: UUID? {
        get {
            guard let string = data[Self.sessionIdKey] else {
                return nil
            }
            return UUID(uuidString: string)
        }
        set {
            data[Self.sessionIdKey] = newValue?.uuidString
        }
    }

}

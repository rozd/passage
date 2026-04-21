public import Foundation
public import Crypto
public import Vapor

public struct BCryptSHA256PasswordHasher: PasswordHasher {
    public let pepper: SymmetricKey
    public let cost: Int

    public init(pepper: SymmetricKey, cost: Int = 12) {
        self.pepper = pepper
        self.cost = cost
    }

    private func preHash<P: DataProtocol>(_ password: P) -> String {
        var hmac = HMAC<SHA512>(key: pepper)
        hmac.update(data: Data(password))
        return Data(hmac.finalize()).base64EncodedString()
    }

    public func hash<P: DataProtocol>(_ password: P) throws -> [UInt8] {
        let digest = try Bcrypt.hash(preHash(password), cost: cost)
        return Array(digest.utf8)
    }

    public func verify<P: DataProtocol, D: DataProtocol>(
        _ password: P, created digest: D
    ) throws -> Bool {
        let hashStr = String(decoding: digest, as: UTF8.self)
        return try Bcrypt.verify(preHash(password), created: hashStr)
    }
}

extension Application.Passwords.Provider {

    public static func bcrypt(pepper: SymmetricKey, cost: Int = 12) -> Self {
        .init {
            $0.passwords.use { _ in
                BCryptSHA256PasswordHasher(pepper: pepper, cost: cost)
            }
        }
    }

}

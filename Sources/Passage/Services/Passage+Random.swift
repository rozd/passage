import Crypto
import Foundation
import Vapor

// MARK: - Random Generator

public extension Passage {

    protocol RandomGenerator: Sendable {
        func generateRandomString(count: Int) -> String
        func generateOpaqueToken() -> String
        func hashOpaqueToken(token: String) -> String
        func generateVerificationCode(length: Int) -> String
    }

}

// MARK: Default Random Generator

struct DefaultRandomGenerator: Passage.RandomGenerator {

    func generateRandomString(count: Int) -> String {
        Data([UInt8].random(count: count)).base64URLEncodedString()
    }
    func generateOpaqueToken() -> String {
        generateRandomString(count: 32)
    }
    func hashOpaqueToken(token: String) -> String {
        SHA256.hash(data: Data(token.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
    func generateVerificationCode(length: Int) -> String {
        // Alphanumeric characters excluding confusing ones (0/O, 1/I/L)
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}

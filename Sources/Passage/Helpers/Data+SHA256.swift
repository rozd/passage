public import Foundation
import Crypto

public extension Data {
    /// SHA-256 digest of the data as a lowercase hex string.
    /// Used by passkey challenge storage to index rows by hash instead of plaintext.
    var sha256Hex: String {
        SHA256.hash(data: self)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

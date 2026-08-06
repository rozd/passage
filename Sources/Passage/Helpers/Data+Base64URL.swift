public import Foundation

// MARK: - base64url Encoding / Decoding

extension Data {
    /// Standard base64 with `+`→`-`, `/`→`_`, and trailing `=` stripped.
    /// Produces a URL-safe base64-encoded string per RFC 4648 §5.
    public func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decode a base64url-encoded string back into `Data`.
    /// Accepts strings with or without `=` padding, and normalizes
    /// `-` → `+` and `_` → `/` before decoding.
    public init?(base64URLEncoded string: String) {
        var normalized = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while normalized.count % 4 != 0 { normalized.append("=") }
        self.init(base64Encoded: normalized)
    }
}
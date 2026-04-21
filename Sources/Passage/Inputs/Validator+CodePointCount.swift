import Vapor

// NIST SP 800-63B §5.1.1.2-f: "each Unicode code point SHALL be counted as a
// single character" for memorized-secret length requirements. Vapor's built-in
// `.count(...)` uses `String.count` (extended grapheme clusters per UAX #29),
// which produces a different — and unstable, since UAX #29 evolves — number.
// This validator mirrors the `.count` API but measures `unicodeScalars.count`
// so transport-layer checks agree with `PasswordPolicy.validate(password:)`.

extension Validator where T == String {

    static func codePointCount(_ range: ClosedRange<Int>) -> Validator<String> {
        .codePointCount(min: range.lowerBound, max: range.upperBound)
    }

    static func codePointCount(_ range: PartialRangeFrom<Int>) -> Validator<String> {
        .codePointCount(min: range.lowerBound, max: nil)
    }

    static func codePointCount(_ range: PartialRangeThrough<Int>) -> Validator<String> {
        .codePointCount(min: nil, max: range.upperBound)
    }

    private static func codePointCount(min: Int?, max: Int?) -> Validator<String> {
        .init { data in
            let count = data.unicodeScalars.count
            if let min, count < min {
                return CodePointCountResult(outcome: .tooShort(min: min))
            }
            if let max, count > max {
                return CodePointCountResult(outcome: .tooLong(max: max))
            }
            return CodePointCountResult(outcome: .inRange(count: count))
        }
    }
}

struct CodePointCountResult: ValidatorResult {
    enum Outcome: Sendable {
        case inRange(count: Int)
        case tooShort(min: Int)
        case tooLong(max: Int)
    }

    let outcome: Outcome

    var isFailure: Bool {
        switch outcome {
        case .inRange: return false
        case .tooShort, .tooLong: return true
        }
    }

    var successDescription: String? { description }
    var failureDescription: String? { description }

    private var description: String {
        switch outcome {
        case .inRange(let count):
            return "is \(count) code point(s)"
        case .tooShort(let min):
            return "is less than minimum of \(min) code point(s)"
        case .tooLong(let max):
            return "is greater than maximum of \(max) code point(s)"
        }
    }
}

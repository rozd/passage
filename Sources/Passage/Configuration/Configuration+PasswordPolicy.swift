public extension Passage.Configuration {

    struct PasswordPolicy: Sendable {
        public let minLength: Int
        public let maxLength: Int
        public let requireUppercase: Bool
        public let requireLowercase: Bool
        public let requireDigit: Bool
        public let requireSpecialCharacter: Bool
        public let breachedPasswordBlocklist: Set<String>
    }

}

public extension Passage.Configuration.PasswordPolicy {

    static func moderate(
        minLength: Int = 8,
        maxLength: Int = 256,
        requireUppercase: Bool = true,
        requireLowercase: Bool = true,
        requireDigit: Bool = true,
        requireSpecialCharacter: Bool = false,
        breachedPasswordBlocklist: Set<String> = [
            "password",
            "12345678",
            "iloveyou",
        ]
    ) -> Self {
        return Self(
            minLength: minLength,
            maxLength: maxLength,
            requireUppercase: requireUppercase,
            requireLowercase: requireLowercase,
            requireDigit: requireDigit,
            requireSpecialCharacter: requireSpecialCharacter,
            breachedPasswordBlocklist: breachedPasswordBlocklist
        )
    }

    static func relaxed(
        minLength: Int = 8,
        maxLength: Int = 256,
        requireUppercase: Bool = false,
        requireLowercase: Bool = false,
        requireDigit: Bool = false,
        requireSpecialCharacter: Bool = false,
        breachedPasswordBlocklist: Set<String> = [
            "password",
            "12345678",
            "iloveyou",
        ]
    ) -> Self {
        return Self(
            minLength: minLength,
            maxLength: maxLength,
            requireUppercase: requireUppercase,
            requireLowercase: requireLowercase,
            requireDigit: requireDigit,
            requireSpecialCharacter: requireSpecialCharacter,
            breachedPasswordBlocklist: breachedPasswordBlocklist
        )
    }
}

extension Passage.Configuration.PasswordPolicy {

    // NIST SP 800-63B §5.1.1.2-g: apply NFKC before hashing so canonically-
    // equivalent forms (e.g. NFC `é` vs NFD `e` + combining acute) authenticate
    // interchangeably regardless of which keyboard or IME produced them.
    func normalize(password: String) -> String {
        password.precomposedStringWithCompatibilityMapping
    }

    func validate(password: String) throws {
        let codePointCount = password.unicodeScalars.count
        if codePointCount < minLength {
            throw PassageError.passwordTooShort(minLength: minLength)
        }
        if codePointCount > maxLength {
            throw PassageError.passwordTooLong(maxLength: maxLength)
        }
        if requireUppercase && !password.contains(where: \.isUppercase) {
            throw PassageError.passwordRequiresUppercase
        }
        if requireLowercase && !password.contains(where: \.isLowercase) {
            throw PassageError.passwordRequiresLowercase
        }
        if requireDigit && !password.contains(where: \.isNumber) {
            throw PassageError.passwordRequiresDigit
        }
        if requireSpecialCharacter && !password.contains(where: { !$0.isLetter && !$0.isNumber }) {
            throw PassageError.passwordRequiresSpecialCharacter
        }
        if breachedPasswordBlocklist.contains(password) {
            throw PassageError.passwordBreached
        }
    }

}

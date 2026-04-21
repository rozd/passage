import Vapor

public protocol PasswordResetRequestForm: Form {
    var identifier: Identifier { get }
}

public protocol PasswordResetVerifyForm: Form {
    var identifier: Identifier { get }
    var code: String { get }
    var newPassword: String { get }
}

// MARK: - Email Password Reset Forms

public protocol EmailPasswordResetRequestForm: PasswordResetRequestForm {
    var email: String { get }
}

public extension EmailPasswordResetRequestForm {
    var identifier: Identifier {
        .email(email)
    }
}

public protocol EmailPasswordResetVerifyForm: PasswordResetVerifyForm {
    var email: String { get }
}

public extension EmailPasswordResetVerifyForm {
    var identifier: Identifier {
        .email(email)
    }
}

public protocol EmailPasswordResetResendForm: Form {
    var email: String { get }
}

// MARK: - Phone Password Reset Forms

public protocol PhonePasswordResetRequestForm: PasswordResetRequestForm {
    var phone: String { get }
}

public extension PhonePasswordResetRequestForm {
    var identifier: Identifier {
        .phone(phone)
    }
}

public protocol PhonePasswordResetVerifyForm: PasswordResetVerifyForm {
    var phone: String { get }
}

public extension PhonePasswordResetVerifyForm {
    var identifier: Identifier {
        .phone(phone)
    }
}

public protocol PhonePasswordResetResendForm: Form {
    var phone: String { get }
}

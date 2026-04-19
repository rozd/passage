import Testing

extension Tag {
    @Tag static var unit: Self
    @Tag static var security: Self
    @Tag static var integration: Self
}

extension Tag {
    @Tag static var login: Self
    @Tag static var register: Self
    @Tag static var verifyEmail: Self
    @Tag static var verifyPhone: Self
    @Tag static var resetPassword: Self
    @Tag static var federatedLogin: Self
    @Tag static var passwordless: Self
    @Tag static var exchangeCode: Self
    @Tag static var passkey: Self
}

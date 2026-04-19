//

public extension Passage {

    struct Contracts: Sendable {
        let loginForm: any LoginForm.Type
        let logoutForm: any LogoutForm.Type
        let registerForm: any RegisterForm.Type
        let refreshTokenForm: any RefreshTokenForm.Type
        let exchangeCodeForm: any ExchangeCodeForm.Type
        let emailVerificationRequestForm: any EmailVerificationRequestForm.Type
        let emailVerificationConfirmForm: any EmailVerificationConfirmForm.Type
        let phoneVerificationRequestForm: any PhoneVerificationRequestForm.Type
        let phoneVerificationConfirmForm: any PhoneVerificationConfirmForm.Type
        let emailPasswordResetRequestForm: any EmailPasswordResetRequestForm.Type
        let emailPasswordResetVerifyForm: any EmailPasswordResetVerifyForm.Type
        let emailPasswordResetResendForm: any EmailPasswordResetResendForm.Type
        let phonePasswordResetRequestForm: any PhonePasswordResetRequestForm.Type
        let phonePasswordResetVerifyForm: any PhonePasswordResetVerifyForm.Type
        let phonePasswordResetResendForm: any PhonePasswordResetResendForm.Type
        let emailMagicLinkRequestForm: any EmailMagicLinkRequestForm.Type
        let emailMagicLinkVerifyForm: any EmailMagicLinkVerifyForm.Type
        let emailMagicLinkResendForm: any EmailMagicLinkResendForm.Type
        let linkAccountSelectForm: any LinkAccountSelectForm.Type
        let linkAccountVerifyForm: any LinkAccountVerifyForm.Type
        let passkeySignupForm: any PasskeySignupForm.Type

        public init(
            loginForm: (any LoginForm.Type)? = nil,
            logoutForm: (any LogoutForm.Type)? = nil,
            registerForm: (any RegisterForm.Type)? = nil,
            refreshTokenForm: (any RefreshTokenForm.Type)? = nil,
            exchangeCodeForm: (any ExchangeCodeForm.Type)? = nil,
            emailVerificationRequestForm: (any EmailVerificationRequestForm.Type)? = nil,
            emailVerificationConfirmForm: (any EmailVerificationConfirmForm.Type)? = nil,
            phoneVerificationRequestForm: (any PhoneVerificationRequestForm.Type)? = nil,
            phoneVerificationConfirmForm: (any PhoneVerificationConfirmForm.Type)? = nil,
            emailPasswordResetRequestForm: (any EmailPasswordResetRequestForm.Type)? = nil,
            emailPasswordResetVerifyForm: (any EmailPasswordResetVerifyForm.Type)? = nil,
            emailPasswordResetResendForm: (any EmailPasswordResetResendForm.Type)? = nil,
            phonePasswordResetRequestForm: (any PhonePasswordResetRequestForm.Type)? = nil,
            phonePasswordResetVerifyForm: (any PhonePasswordResetVerifyForm.Type)? = nil,
            phonePasswordResetResendForm: (any PhonePasswordResetResendForm.Type)? = nil,
            emailMagicLinkRequestForm: (any EmailMagicLinkRequestForm.Type)? = nil,
            emailMagicLinkVerifyForm: (any EmailMagicLinkVerifyForm.Type)? = nil,
            emailMagicLinkResendForm: (any EmailMagicLinkResendForm.Type)? = nil,
            linkAccountSelectForm: (any LinkAccountSelectForm.Type)? = nil,
            linkAccountVerifyForm: (any LinkAccountVerifyForm.Type)? = nil,
            passkeySignupForm: (any PasskeySignupForm.Type)? = nil
        ) {
            self.loginForm = loginForm ?? DefaultLoginForm.self
            self.logoutForm = logoutForm ?? DefaultLogoutForm.self
            self.registerForm = registerForm ?? DefaultRegisterForm.self
            self.refreshTokenForm = refreshTokenForm ?? DefaultRefreshTokenForm.self
            self.exchangeCodeForm = exchangeCodeForm ?? DefaultExchangeCodeForm.self
            self.emailVerificationRequestForm = emailVerificationRequestForm ?? DefaultEmailVerificationRequestForm.self
            self.emailVerificationConfirmForm = emailVerificationConfirmForm ?? DefaultEmailVerificationConfirmForm.self
            self.phoneVerificationRequestForm = phoneVerificationRequestForm ?? DefaultPhoneVerificationRequestForm.self
            self.phoneVerificationConfirmForm = phoneVerificationConfirmForm ?? DefaultPhoneVerificationConfirmForm.self
            self.emailPasswordResetRequestForm = emailPasswordResetRequestForm ?? DefaultEmailPasswordResetRequestForm.self
            self.emailPasswordResetVerifyForm = emailPasswordResetVerifyForm ?? DefaultEmailPasswordResetVerifyForm.self
            self.emailPasswordResetResendForm = emailPasswordResetResendForm ?? DefaultEmailPasswordResetResendForm.self
            self.phonePasswordResetRequestForm = phonePasswordResetRequestForm ?? DefaultPhonePasswordResetRequestForm.self
            self.phonePasswordResetVerifyForm = phonePasswordResetVerifyForm ?? DefaultPhonePasswordResetVerifyForm.self
            self.phonePasswordResetResendForm = phonePasswordResetResendForm ?? DefaultPhonePasswordResetResendForm.self
            self.emailMagicLinkRequestForm = emailMagicLinkRequestForm ?? DefaultEmailMagicLinkRequestForm.self
            self.emailMagicLinkVerifyForm = emailMagicLinkVerifyForm ?? DefaultEmailMagicLinkVerifyForm.self
            self.emailMagicLinkResendForm = emailMagicLinkResendForm ?? DefaultEmailMagicLinkResendForm.self
            self.linkAccountSelectForm = linkAccountSelectForm ?? DefaultLinkAccountSelectForm.self
            self.linkAccountVerifyForm = linkAccountVerifyForm ?? DefaultLinkAccountVerifyForm.self
            self.passkeySignupForm = passkeySignupForm ?? DefaultPasskeySignupForm.self
        }
    }

}

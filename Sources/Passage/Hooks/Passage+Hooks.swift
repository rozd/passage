public extension Passage {

    struct Hooks: Sendable {
        public let account: (any Account)?
        public let passkey: (any Passkey)?

        public init(
            account: (any Account)? = nil,
            passkey: (any Passkey)? = nil,
        ) {
            self.account = account
            self.passkey = passkey
        }
    }

}

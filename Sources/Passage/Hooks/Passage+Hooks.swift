public extension Passage {

    struct Hooks: Sendable {
        public let account: (any Account)?

        public init(
            account: (any Account)? = nil,
        ) {
            self.account = account
        }
    }

}

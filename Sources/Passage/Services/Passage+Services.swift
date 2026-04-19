import Foundation

// MARK: - Services

public extension Passage {

    struct Services: Sendable {
        let store: any Store
        let random: any RandomGenerator
        let emailDelivery: (any EmailDelivery)?
        let phoneDelivery: (any PhoneDelivery)?
        let federatedLogin: (any FederatedLoginService)?
        let passkey: (any PasskeyService)?

        public init(
            store: any Store,
            random: any RandomGenerator,
            emailDelivery: (any EmailDelivery)?,
            phoneDelivery: (any PhoneDelivery)?,
            federatedLogin: (any FederatedLoginService)? = nil,
            passkey: (any PasskeyService)? = nil,
        ) {
            self.store = store
            self.random = random
            self.emailDelivery = emailDelivery
            self.phoneDelivery = phoneDelivery
            self.federatedLogin = federatedLogin
            self.passkey = passkey
        }

        public init(
            store: any Store,
            emailDelivery: (any EmailDelivery)?,
            phoneDelivery: (any PhoneDelivery)?,
            federatedLogin: (any FederatedLoginService)? = nil,
            passkey: (any PasskeyService)? = nil,
        ) {
            self.store = store
            self.random = DefaultRandomGenerator()
            self.emailDelivery = emailDelivery
            self.phoneDelivery = phoneDelivery
            self.federatedLogin = federatedLogin
            self.passkey = passkey
        }
    }
}

// MARK: - Delivery Type

public extension Passage {

    enum DeliveryType: Sendable {
        case email
        case phone
    }

}

// MARK: - Service Accessors

extension Passage {

    var store: any Store {
        services.store
    }

    var random: any RandomGenerator {
        services.random
    }

    var emailDelivery: (any EmailDelivery)? {
        services.emailDelivery
    }

    var phoneDelivery: (any PhoneDelivery)? {
        services.phoneDelivery
    }

    var federatedLogin: (any FederatedLoginService)? {
        services.federatedLogin
    }

    var passkey: (any PasskeyService)? {
        services.passkey
    }
}

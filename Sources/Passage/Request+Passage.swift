public import Vapor

// MARK: - Passage User Provider

public extension Request {

    var passage: PassageContext {
        .init(request: self)
    }

}

// MARK: - Service Accessors

extension Request {

    var contracts: Passage.Contracts {
        application.passage.contracts
    }

    var services: Passage.Services {
        application.passage.services
    }

    var store: any Passage.Store {
        application.passage.store
    }

    var emailDelivery: (any Passage.EmailDelivery)? {
        application.passage.emailDelivery
    }

    var phoneDelivery: (any Passage.PhoneDelivery)? {
        application.passage.phoneDelivery
    }

    var configuration: Passage.Configuration {
        application.passage.configuration
    }

    var random: any Passage.RandomGenerator {
        application.passage.random
    }

    var throttle: any Passage.Throttle.Service {
        application.passage.throttle
    }

}

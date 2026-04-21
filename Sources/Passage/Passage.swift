import JWT
import Queues
import Vapor

public struct Passage: Sendable {

    init(app: Application) {
        self.app = app
    }

    let app: Application

    // MARK: - Configuration

    public func configure(
        services: Services,
        contracts: Contracts = .init(),
        configuration: Configuration,
    ) async throws {

        self.storage = Storage(
            services: services,
            contracts: contracts,
            configuration: configuration
        )

        try await app.jwt.keys.add(jwksJSON: configuration.jwt.jwks.json)

        try app.register(collection: Account.RouteCollection(routes: configuration.routes))
        try app.register(collection: Tokens.RouteCollection(routes: configuration.routes))

        if let _ = services.emailDelivery {
            // Register email verification routes if delivery is provided
            try app.register(collection: Verification.EmailRouteCollection(
                config: configuration.verification.email,
                group: configuration.routes.group
            ))
            // Register email password reset routes if delivery is provided
            try app.register(collection: Restoration.EmailRouteCollection(
                routes: configuration.restoration.email.routes,
                group: configuration.routes.group
            ))
            // Register email magic link routes for passwordless authentication
            if let emailMagicLink = configuration.passwordless.emailMagicLink {
                try app.register(collection: Passwordless.MagicLinkEmailRouteCollection(
                    routes: emailMagicLink.routes,
                    group: configuration.routes.group
                ))
            }
        }

        if let _ = services.phoneDelivery {
            // Register phone verification routes if delivery is provided
            try app.register(collection: Verification.PhoneRouteCollection(
                config: configuration.verification.phone,
                groupPath: configuration.routes.group
            ))
            // Register phone password reset routes if delivery is provided
            try app.register(collection: Restoration.PhoneRouteCollection(
                routes: configuration.restoration.phone.routes,
                groupPath: configuration.routes.group
            ))
        }

        //
        if configuration.views.enabled {
            try Views.registerLeafTempleates(on: app)
            try app.register(collection: Views.RouteCollection(
                group: configuration.routes.group,
                config: configuration.views,
                routes: configuration.routes,
                restoration: configuration.restoration,
                passwordless: configuration.passwordless,
                federatedLogin: configuration.federatedLogin,
                passkey: configuration.passkey,
            ))
        }

        if configuration.federatedLogin.accountLinking.enabled {
            try app.register(collection: Linking.RouteCollection(
                configuration: configuration
            ))
        }

        if let _ = services.passkey {
            try app.register(collection: Passkey.RouteCollection(
                routes: configuration.passkey.routes,
                groupPath: configuration.routes.group,
            ))
        }

        // Register verification jobs if queues are enabled
        if configuration.verification.useQueues {
            app.queues.add(Verification.SendEmailCodeJob())
            app.queues.add(Verification.SendPhoneCodeJob())
        }

        // Register restoration jobs if queues are enabled
        if configuration.restoration.useQueues {
            app.queues.add(Restoration.SendEmailPasswordResetCodeJob())
            app.queues.add(Restoration.SendPhonePasswordResetCodeJob())
        }

        // Register passwordless jobs if queues are enabled
        if configuration.passwordless.emailMagicLink?.useQueues == true {
            app.queues.add(Passwordless.SendEmailMagicLinkJob())
        }

        try FederatedLoginHandler(app: app, configuration: configuration).register()
    }

}

// MARK: - Storage Accessors

extension Passage {

    var services: Services {
        storage.services
    }

    var contracts: Contracts {
        storage.contracts
    }

    var configuration: Configuration {
        storage.configuration
    }

}

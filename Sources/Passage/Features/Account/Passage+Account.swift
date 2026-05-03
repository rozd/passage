import JWT
import Vapor

extension Passage {

    struct Account: Sendable {
        let request: Request
    }
}

// MARK: - Request Extension

extension Request {
    var account: Passage.Account {
        Passage.Account(request: self)
    }
}

// MARK: - Service Accessors

extension Passage.Account {
    
    var store: any Passage.Store {
        request.store
    }

    var configuration: Passage.Configuration {
        request.configuration
    }

    var verification: Passage.Verification {
        request.verification
    }
}

// MARK: - Register

extension Passage.Account {

    func register(form: any RegisterForm) async throws {
        let policy = request.configuration.passwordPolicy

        try await request.hooks.account?.willRegister(with: form, on: request)

        let password = form.password
        try policy.validate(password: password)

        let hash = try await request.password.async.hash(policy.normalize(password: password))

        let identifier = try form.asIdentifier()

        let user = try await store.users.create(identifier: identifier, with: .password(hash))

        await request.hooks.account?.didRegister(user: user, on: request)

        // Fire-and-forget: don't fail registration if verification send fails
        try? await verification.sendVerificationCode(
            for: user,
            identifierKind: identifier.kind
        )
    }

}

// MARK: - Login

extension Passage.Account {

    func login(form: any LoginForm) async throws -> AuthUser {
        let identifier = try form.asIdentifier()
        let rules = configuration.throttle.login
        let now = Date()
        let idBucket = Passage.Throttle.Bucket(
            scope: .login,
            dimension: .identifier(kind: identifier.kind, value: identifier.value),
            enabled: rules.enabled
        )

        if case let .throttled(delay) = await request.throttle.check(
            bucket: idBucket, against: rules.perIdentifier, at: now
        ) {
            throw AuthenticationError.tooManyLoginAttempts(retryAfter: delay)
        }

        guard let user = try await store.users.find(byIdentifier: identifier) else {
            await request.throttle.penalize(bucket: idBucket, at: now)
            throw identifier.errorWhenIdentifierIsInvalid
        }

        guard let userPasswordHash = user.passwordHash else {
            throw AuthenticationError.passwordIsNotSet
        }

        try user.check(identifier: identifier)

        let policy = request.configuration.passwordPolicy
        let passwordNormalized = policy.normalize(password: form.password)

        guard try await request.password.async.verify(passwordNormalized, created: userPasswordHash) else {
            await request.throttle.penalize(bucket: idBucket, at: now)
            throw identifier.errorWhenIdentifierIsInvalid
        }

        await request.throttle.reset(bucket: idBucket)

        try await request.hooks.account?.willLogin(user: user, on: request)

        request.passage.login(user)

        await request.hooks.account?.didLogin(user: user, on: request)

        return try await request.tokens.issue(for: user)
    }

}

// MARK: - Logout

extension Passage.Account {

    func logout() async throws {
        guard let user = try? request.passage.user else {
            return
        }

        try await request.hooks.account?.willLogout(user: user, on: request)

        request.passage.logout()

        await request.hooks.account?.didLogout(user: user, on: request)

        try await request.tokens.revoke(for: user)
    }

}

// MARK: - Current User

extension Passage.Account {

    func user(for accessToken: AccessToken) async throws -> any User {
        let userId = accessToken.subject.value

        guard let user = try await store.users.find(byId: userId) else {
            throw AuthenticationError.userNotFound
        }

        return user
    }

    func user(withId userId: String) async throws -> any User {
        guard let user = try await store.users.find(byId: userId) else {
            throw AuthenticationError.userNotFound
        }

        return user
    }

    func currentUser() throws -> AuthUser.User {

        let user = try request.passage.user

        return .init(
            id: try user.requiredIdAsString,
            email: user.email,
            phone: user.phone
        )
    }

}

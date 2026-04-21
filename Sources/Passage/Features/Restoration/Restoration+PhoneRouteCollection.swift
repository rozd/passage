import Vapor

extension Passage.Restoration {

    struct PhoneRouteCollection: Vapor.RouteCollection, Sendable {

        let routes: Passage.Configuration.Restoration.Phone.Routes
        let groupPath: [PathComponent]

        func boot(routes builder: any RoutesBuilder) throws {
            let grouped = groupPath.isEmpty ? builder : builder.grouped(groupPath)

            grouped.post(routes.request.path, use: request)
            grouped.post(routes.verify.path, use: verify)
            grouped.post(routes.resend.path, use: resend)
        }

    }

}

// MARK: - Request Reset

extension Passage.Restoration.PhoneRouteCollection {

    func request(_ req: Request) async throws -> HTTPStatus {
        let form = try req.decodeContentAsFormOfType(req.contracts.phonePasswordResetRequestForm)
        try await req.restoration.requestReset(for: .phone(form.phone))
        return .ok
    }

}

// MARK: - Verify and Reset Password

extension Passage.Restoration.PhoneRouteCollection {

    func verify(_ req: Request) async throws -> HTTPStatus {
        let form = try req.decodeContentAsFormOfType(req.contracts.phonePasswordResetVerifyForm)

        try await req.restoration.verifyReset(form: form)

        return .ok
    }

}

// MARK: - Resend

extension Passage.Restoration.PhoneRouteCollection {

    struct ResendForm: Content {
        let phone: String
    }

    func resend(_ req: Request) async throws -> HTTPStatus {
        let form = try req.decodeContentAsFormOfType(req.contracts.phonePasswordResetResendForm)
        try await req.restoration.resendPasswordResetCode(toPhone: form.phone)
        return .ok
    }

}

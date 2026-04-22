import Testing
import Vapor
import NIOCore
@testable import Passage

@Suite(.primeNIOSingletons)
struct `Form Detection Tests` {

    // MARK: - isFormSubmission Tests

    @Test
    func `isFormSubmission returns true for application/x-www-form-urlencoded`() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .POST,
                url: .init(string: "/test"),
                on: app.eventLoopGroup.any()
            )
            req.headers.contentType = .urlEncodedForm
            #expect(req.isFormSubmission == true)
        }
    }

    @Test
    func `isFormSubmission returns true for multipart/form-data`() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .POST,
                url: .init(string: "/test"),
                on: app.eventLoopGroup.any()
            )
            req.headers.contentType = .formData
            #expect(req.isFormSubmission == true)
        }
    }

    @Test
    func `isFormSubmission returns false for application/json`() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .POST,
                url: .init(string: "/test"),
                on: app.eventLoopGroup.any()
            )
            req.headers.contentType = .json
            #expect(req.isFormSubmission == false)
        }
    }

    @Test
    func `isFormSubmission returns false when no content type`() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .GET,
                url: .init(string: "/test"),
                on: app.eventLoopGroup.any()
            )
            #expect(req.isFormSubmission == false)
        }
    }

    // MARK: - isWaitingForHTML Tests

    @Test
    func `isWaitingForHTML returns true for text/html accept header`() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .GET,
                url: .init(string: "/test"),
                on: app.eventLoopGroup.any()
            )
            req.headers.add(name: .accept, value: "text/html")
            #expect(req.isWaitingForHTML == true)
        }
    }

    @Test
    func `isWaitingForHTML returns true for text/html with charset`() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .GET,
                url: .init(string: "/test"),
                on: app.eventLoopGroup.any()
            )
            req.headers.add(name: .accept, value: "text/html; charset=utf-8")
            #expect(req.isWaitingForHTML == true)
        }
    }

    @Test
    func `isWaitingForHTML returns true for text/html in complex accept header`() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .GET,
                url: .init(string: "/test"),
                on: app.eventLoopGroup.any()
            )
            req.headers.add(name: .accept, value: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            #expect(req.isWaitingForHTML == true)
        }
    }

    @Test
    func `isWaitingForHTML returns false for application/json accept header`() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .GET,
                url: .init(string: "/test"),
                on: app.eventLoopGroup.any()
            )
            req.headers.add(name: .accept, value: "application/json")
            #expect(req.isWaitingForHTML == false)
        }
    }

    @Test
    func `isWaitingForHTML returns false when no accept header`() async throws {
        try await withApp { app in
            let req = Request(
                application: app,
                method: .GET,
                url: .init(string: "/test"),
                on: app.eventLoopGroup.any()
            )
            #expect(req.isWaitingForHTML == false)
        }
    }

    // MARK: - Helper

    @Sendable private func withApp(
        _ closure: @Sendable (Application) async throws -> Void
    ) async throws {
        let app = try await Application.make(.testing)
        defer { Task { try? await app.asyncShutdown() } }
        try await closure(app)
    }
}

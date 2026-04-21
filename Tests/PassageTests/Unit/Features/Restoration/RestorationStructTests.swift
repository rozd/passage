import Testing
import Vapor
@testable import Passage

@Suite
struct `Restoration Struct Tests` {

    // MARK: - Restoration Struct Tests

    @Test
    func `Restoration struct is properly namespaced in Passage`() {
        let typeName = String(reflecting: Passage.Restoration.self)
        #expect(typeName.contains("Passage.Restoration"))
    }

    @Test
    func `Restoration struct conforms to Sendable`() {
        let _: any Sendable.Type = Passage.Restoration.self
        #expect(Passage.Restoration.self is (any Sendable).Type)
    }

    // MARK: - EmailPasswordResetCodePayload Tests

    @Test
    func `EmailPasswordResetCodePayload initialization`() throws {
        let url = try #require(URL(string: "https://example.com/reset?code=123&email=test@example.com"))
        let payload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: "user123",
            resetURL: url,
            resetCode: "123456"
        )

        #expect(payload.email == "test@example.com")
        #expect(payload.userId == "user123")
        #expect(payload.resetURL == url)
        #expect(payload.resetCode == "123456")
    }

    @Test
    func `EmailPasswordResetCodePayload conforms to Codable`() throws {
        let url = try #require(URL(string: "https://example.com/reset"))
        let payload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: "user123",
            resetURL: url,
            resetCode: "ABC123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        #expect(!data.isEmpty)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Passage.Restoration.EmailPasswordResetCodePayload.self, from: data)

        #expect(decoded.email == payload.email)
        #expect(decoded.userId == payload.userId)
        #expect(decoded.resetURL == payload.resetURL)
        #expect(decoded.resetCode == payload.resetCode)
    }

    @Test
    func `EmailPasswordResetCodePayload with different URLs`() throws {
        let urls = [
            "https://example.com/reset",
            "https://myapp.com/password-reset",
            "https://app.example.com/v1/reset-password"
        ]

        for urlString in urls {
            let url = try #require(URL(string: urlString))
            let payload = Passage.Restoration.EmailPasswordResetCodePayload(
                email: "test@example.com",
                userId: "user123",
                resetURL: url,
                resetCode: "123456"
            )
            #expect(payload.resetURL.absoluteString == urlString)
        }
    }

    @Test
    func `EmailPasswordResetCodePayload round trip encoding`() throws {
        let url = try #require(URL(string: "https://example.com/reset?code=XYZ&email=user@example.com"))
        let original = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "user@example.com",
            userId: "user456",
            resetURL: url,
            resetCode: "XYZ789"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Passage.Restoration.EmailPasswordResetCodePayload.self, from: data)

        #expect(decoded.email == original.email)
        #expect(decoded.userId == original.userId)
        #expect(decoded.resetURL == original.resetURL)
        #expect(decoded.resetCode == original.resetCode)
    }

    @Test
    func `EmailPasswordResetCodePayload JSON encoding format`() throws {
        let url = try #require(URL(string: "https://example.com/reset"))
        let payload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: "user123",
            resetURL: url,
            resetCode: "123456"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(payload)
        let json = String(data: data, encoding: .utf8)

        #expect(json != nil)
        #expect(json!.contains("\"email\""))
        #expect(json!.contains("\"userId\""))
        #expect(json!.contains("\"resetURL\""))
        #expect(json!.contains("\"resetCode\""))
    }

    // MARK: - PhonePasswordResetCodePayload Tests

    @Test
    func `PhonePasswordResetCodePayload initialization`() {
        let payload = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: "123456",
            userId: "user123"
        )

        #expect(payload.phone == "+1234567890")
        #expect(payload.code == "123456")
        #expect(payload.userId == "user123")
    }

    @Test
    func `PhonePasswordResetCodePayload conforms to Codable`() throws {
        let payload = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: "ABC123",
            userId: "user123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        #expect(!data.isEmpty)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Passage.Restoration.PhonePasswordResetCodePayload.self, from: data)

        #expect(decoded.phone == payload.phone)
        #expect(decoded.code == payload.code)
        #expect(decoded.userId == payload.userId)
    }

    @Test("PhonePasswordResetCodePayload with different phone formats", arguments: [
        "+1234567890",
        "+44 7700 900000",
        "+81 90-1234-5678",
        "555-0123"
    ])
    func phonePayloadPhoneFormats(phone: String) {
        let payload = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: phone,
            code: "123456",
            userId: "user123"
        )
        #expect(payload.phone == phone)
    }

    @Test
    func `PhonePasswordResetCodePayload round trip encoding`() throws {
        let original = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+19876543210",
            code: "XYZ789",
            userId: "user789"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Passage.Restoration.PhonePasswordResetCodePayload.self, from: data)

        #expect(decoded.phone == original.phone)
        #expect(decoded.code == original.code)
        #expect(decoded.userId == original.userId)
    }

    @Test
    func `PhonePasswordResetCodePayload JSON encoding format`() throws {
        let payload = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: "123456",
            userId: "user123"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(payload)
        let json = String(data: data, encoding: .utf8)

        #expect(json != nil)
        #expect(json!.contains("\"phone\""))
        #expect(json!.contains("\"code\""))
        #expect(json!.contains("\"userId\""))
    }

    // MARK: - Payload Independence Tests

    @Test
    func `Email and phone payloads are independent`() throws {
        let url = try #require(URL(string: "https://example.com/reset"))
        let emailPayload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: "user1",
            resetURL: url,
            resetCode: "ABC123"
        )

        let phonePayload = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: "XYZ789",
            userId: "user2"
        )

        #expect(emailPayload.userId != phonePayload.userId)
        #expect(emailPayload.resetCode != phonePayload.code)
    }

    @Test
    func `Multiple email payloads can coexist`() throws {
        let url1 = try #require(URL(string: "https://example.com/reset1"))
        let url2 = try #require(URL(string: "https://example.com/reset2"))

        let payload1 = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "user1@example.com",
            userId: "user1",
            resetURL: url1,
            resetCode: "CODE1"
        )

        let payload2 = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "user2@example.com",
            userId: "user2",
            resetURL: url2,
            resetCode: "CODE2"
        )

        #expect(payload1.email != payload2.email)
        #expect(payload1.userId != payload2.userId)
        #expect(payload1.resetCode != payload2.resetCode)
    }

    @Test
    func `Multiple phone payloads can coexist`() {
        let payload1 = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: "CODE1",
            userId: "user1"
        )

        let payload2 = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+9876543210",
            code: "CODE2",
            userId: "user2"
        )

        #expect(payload1.phone != payload2.phone)
        #expect(payload1.code != payload2.code)
        #expect(payload1.userId != payload2.userId)
    }

    // MARK: - Reset Code Format Tests

    @Test("EmailPasswordResetCodePayload with different code formats", arguments: [
        "123456",
        "ABC123",
        "A1B2C3",
        "000000"
    ])
    func emailPayloadCodeFormats(code: String) throws {
        let url = try #require(URL(string: "https://example.com/reset"))
        let payload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: "user123",
            resetURL: url,
            resetCode: code
        )
        #expect(payload.resetCode == code)
    }

    @Test("PhonePasswordResetCodePayload with different code formats", arguments: [
        "123456",
        "ABC123",
        "A1B2C3",
        "000000"
    ])
    func phonePayloadCodeFormats(code: String) {
        let payload = Passage.Restoration.PhonePasswordResetCodePayload(
            phone: "+1234567890",
            code: code,
            userId: "user123"
        )
        #expect(payload.code == code)
    }

    // MARK: - URL Query Parameters Tests

    @Test
    func `EmailPasswordResetCodePayload with URL containing query parameters`() throws {
        let url = try #require(URL(string: "https://example.com/reset?code=123&email=test@example.com&token=xyz"))
        let payload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: "user123",
            resetURL: url,
            resetCode: "123456"
        )

        #expect(payload.resetURL.query != nil)
        #expect(payload.resetURL.query!.contains("code=123"))
        #expect(payload.resetURL.query!.contains("email="))
    }

    @Test
    func `EmailPasswordResetCodePayload with complex reset URL`() throws {
        let url = try #require(URL(string: "https://app.example.com/auth/reset-password?step=verify&token=abc123&redirect=/dashboard"))
        let payload = Passage.Restoration.EmailPasswordResetCodePayload(
            email: "test@example.com",
            userId: "user123",
            resetURL: url,
            resetCode: "123456"
        )

        #expect(payload.resetURL.host == "app.example.com")
        #expect(payload.resetURL.path == "/auth/reset-password")
        #expect(payload.resetURL.query != nil)
    }

    // MARK: - Nested Type Tests

    @Test
    func `EmailPasswordResetCodePayload is nested in Restoration`() {
        let typeName = String(reflecting: Passage.Restoration.EmailPasswordResetCodePayload.self)
        #expect(typeName.contains("Passage.Restoration.EmailPasswordResetCodePayload"))
    }

    @Test
    func `PhonePasswordResetCodePayload is nested in Restoration`() {
        let typeName = String(reflecting: Passage.Restoration.PhonePasswordResetCodePayload.self)
        #expect(typeName.contains("Passage.Restoration.PhonePasswordResetCodePayload"))
    }

    @Test
    func `SendEmailPasswordResetCodeJob is nested in Restoration`() {
        let typeName = String(reflecting: Passage.Restoration.SendEmailPasswordResetCodeJob.self)
        #expect(typeName.contains("Passage.Restoration.SendEmailPasswordResetCodeJob"))
    }

    @Test
    func `SendPhonePasswordResetCodeJob is nested in Restoration`() {
        let typeName = String(reflecting: Passage.Restoration.SendPhonePasswordResetCodeJob.self)
        #expect(typeName.contains("Passage.Restoration.SendPhonePasswordResetCodeJob"))
    }
}

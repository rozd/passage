import Testing
import Vapor
@testable import Passage

@Suite
struct `Verification Struct Tests` {

    // MARK: - Verification Struct Tests

    @Test
    func `Verification struct is properly namespaced in Passage`() {
        let typeName = String(reflecting: Passage.Verification.self)
        #expect(typeName.contains("Passage.Verification"))
    }

    @Test
    func `Verification struct conforms to Sendable`() {
        let _: any Sendable.Type = Passage.Verification.self
    }

    // MARK: - SendEmailCodePayload Tests

    @Test
    func `SendEmailCodePayload initialization`() throws {
        let url = try #require(URL(string: "https://example.com/verify?code=123456"))
        let payload = Passage.Verification.SendEmailCodePayload(
            email: "test@example.com",
            userId: "user123",
            verificationURL: url,
            verificationCode: "123456"
        )

        #expect(payload.email == "test@example.com")
        #expect(payload.userId == "user123")
        #expect(payload.verificationURL == url)
        #expect(payload.verificationCode == "123456")
    }

    @Test
    func `SendEmailCodePayload conforms to Codable`() throws {
        let url = try #require(URL(string: "https://example.com/verify"))
        let payload = Passage.Verification.SendEmailCodePayload(
            email: "test@example.com",
            userId: "user123",
            verificationURL: url,
            verificationCode: "ABC123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        #expect(!data.isEmpty)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Passage.Verification.SendEmailCodePayload.self, from: data)

        #expect(decoded.email == payload.email)
        #expect(decoded.userId == payload.userId)
        #expect(decoded.verificationURL == payload.verificationURL)
        #expect(decoded.verificationCode == payload.verificationCode)
    }

    @Test
    func `SendEmailCodePayload with different verification URLs`() throws {
        let urls = [
            "https://example.com/verify",
            "https://myapp.com/auth/verify",
            "https://app.example.com/v1/verify"
        ]

        for urlString in urls {
            let url = try #require(URL(string: urlString))
            let payload = Passage.Verification.SendEmailCodePayload(
                email: "test@example.com",
                userId: "user123",
                verificationURL: url,
                verificationCode: "123456"
            )
            #expect(payload.verificationURL.absoluteString == urlString)
        }
    }

    @Test
    func `SendEmailCodePayload encodes and decodes correctly`() throws {
        let url = try #require(URL(string: "https://example.com/verify?code=ABC123"))
        let original = Passage.Verification.SendEmailCodePayload(
            email: "user@example.com",
            userId: "user456",
            verificationURL: url,
            verificationCode: "ABC123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Passage.Verification.SendEmailCodePayload.self, from: data)

        #expect(decoded.email == original.email)
        #expect(decoded.userId == original.userId)
        #expect(decoded.verificationURL == original.verificationURL)
        #expect(decoded.verificationCode == original.verificationCode)
    }

    // MARK: - SendPhoneCodePayload Tests

    @Test
    func `SendPhoneCodePayload initialization`() {
        let payload = Passage.Verification.SendPhoneCodePayload(
            phone: "+1234567890",
            code: "123456",
            userId: "user123"
        )

        #expect(payload.phone == "+1234567890")
        #expect(payload.code == "123456")
        #expect(payload.userId == "user123")
    }

    @Test
    func `SendPhoneCodePayload conforms to Codable`() throws {
        let payload = Passage.Verification.SendPhoneCodePayload(
            phone: "+1234567890",
            code: "ABC123",
            userId: "user123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        #expect(!data.isEmpty)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Passage.Verification.SendPhoneCodePayload.self, from: data)

        #expect(decoded.phone == payload.phone)
        #expect(decoded.code == payload.code)
        #expect(decoded.userId == payload.userId)
    }

    @Test(arguments: [
        "+1234567890",
        "+44 7700 900000",
        "+81 90-1234-5678",
        "555-0123"
    ])
    func `SendPhoneCodePayload with different phone formats`(phone: String) {
        let payload = Passage.Verification.SendPhoneCodePayload(
            phone: phone,
            code: "123456",
            userId: "user123"
        )
        #expect(payload.phone == phone)
    }

    @Test
    func `SendPhoneCodePayload encodes and decodes correctly`() throws {
        let original = Passage.Verification.SendPhoneCodePayload(
            phone: "+19876543210",
            code: "XYZ789",
            userId: "user789"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Passage.Verification.SendPhoneCodePayload.self, from: data)

        #expect(decoded.phone == original.phone)
        #expect(decoded.code == original.code)
        #expect(decoded.userId == original.userId)
    }

    // MARK: - Payload Independence Tests

    @Test
    func `Email and phone payloads are independent`() throws {
        let url = try #require(URL(string: "https://example.com/verify"))
        let emailPayload = Passage.Verification.SendEmailCodePayload(
            email: "test@example.com",
            userId: "user1",
            verificationURL: url,
            verificationCode: "ABC123"
        )

        let phonePayload = Passage.Verification.SendPhoneCodePayload(
            phone: "+1234567890",
            code: "XYZ789",
            userId: "user2"
        )

        #expect(emailPayload.userId != phonePayload.userId)
        #expect(emailPayload.verificationCode != phonePayload.code)
    }

    @Test
    func `Multiple email payloads can coexist`() throws {
        let url1 = try #require(URL(string: "https://example.com/verify1"))
        let url2 = try #require(URL(string: "https://example.com/verify2"))

        let payload1 = Passage.Verification.SendEmailCodePayload(
            email: "user1@example.com",
            userId: "user1",
            verificationURL: url1,
            verificationCode: "CODE1"
        )

        let payload2 = Passage.Verification.SendEmailCodePayload(
            email: "user2@example.com",
            userId: "user2",
            verificationURL: url2,
            verificationCode: "CODE2"
        )

        #expect(payload1.email != payload2.email)
        #expect(payload1.userId != payload2.userId)
        #expect(payload1.verificationCode != payload2.verificationCode)
    }

    @Test
    func `Multiple phone payloads can coexist`() {
        let payload1 = Passage.Verification.SendPhoneCodePayload(
            phone: "+1234567890",
            code: "CODE1",
            userId: "user1"
        )

        let payload2 = Passage.Verification.SendPhoneCodePayload(
            phone: "+9876543210",
            code: "CODE2",
            userId: "user2"
        )

        #expect(payload1.phone != payload2.phone)
        #expect(payload1.code != payload2.code)
        #expect(payload1.userId != payload2.userId)
    }

    // MARK: - JSON Encoding Tests

    @Test
    func `SendEmailCodePayload JSON encoding format`() throws {
        let url = try #require(URL(string: "https://example.com/verify"))
        let payload = Passage.Verification.SendEmailCodePayload(
            email: "test@example.com",
            userId: "user123",
            verificationURL: url,
            verificationCode: "123456"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(payload)
        let json = String(data: data, encoding: .utf8)

        #expect(json != nil)
        #expect(json!.contains("\"email\""))
        #expect(json!.contains("\"userId\""))
        #expect(json!.contains("\"verificationURL\""))
        #expect(json!.contains("\"verificationCode\""))
    }

    @Test
    func `SendPhoneCodePayload JSON encoding format`() throws {
        let payload = Passage.Verification.SendPhoneCodePayload(
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

    // MARK: - Verification Code Format Tests

    @Test(arguments: [
        "123456",
        "ABC123",
        "A1B2C3",
        "000000"
    ])
    func `SendEmailCodePayload with different code formats`(code: String) throws {
        let url = try #require(URL(string: "https://example.com/verify"))
        let payload = Passage.Verification.SendEmailCodePayload(
            email: "test@example.com",
            userId: "user123",
            verificationURL: url,
            verificationCode: code
        )
        #expect(payload.verificationCode == code)
    }

    @Test(arguments: [
        "123456",
        "ABC123",
        "A1B2C3",
        "000000"
    ])
    func `SendPhoneCodePayload with different code formats`(code: String) {
        let payload = Passage.Verification.SendPhoneCodePayload(
            phone: "+1234567890",
            code: code,
            userId: "user123"
        )
        #expect(payload.code == code)
    }

    // MARK: - URL Query Parameters Tests

    @Test
    func `SendEmailCodePayload with URL containing query parameters`() throws {
        let url = try #require(URL(string: "https://example.com/verify?code=123456&email=test@example.com"))
        let payload = Passage.Verification.SendEmailCodePayload(
            email: "test@example.com",
            userId: "user123",
            verificationURL: url,
            verificationCode: "123456"
        )

        #expect(payload.verificationURL.query != nil)
        #expect(payload.verificationURL.query!.contains("code=123456"))
    }
}

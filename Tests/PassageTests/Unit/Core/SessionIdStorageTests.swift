@testable import Passage
import Foundation
import Testing
import Vapor

@Suite(.tags(.unit))
struct `Session ID Storage Tests` {

    @Test
    func `set sessionId stores UUID string in data`() {
        let session = Session(id: SessionID(string: "test-session"), data: [:])
        let uuid = UUID()

        session.sessionId = uuid

        #expect(session.data[Session.sessionIdKey] == uuid.uuidString)
    }

    @Test
    func `get sessionId round-trips UUID`() {
        let uuid = UUID()
        let session = Session(id: SessionID(string: "test-session"), data: [:])
        session.sessionId = uuid

        let retrieved = session.sessionId

        #expect(retrieved == uuid)
    }

    @Test
    func `set sessionId to nil removes key from data`() {
        let session = Session(id: SessionID(string: "test-session"), data: [:])
        let uuid = UUID()
        session.sessionId = uuid

        session.sessionId = nil

        #expect(session.data[Session.sessionIdKey] == nil)
    }

    @Test
    func `get sessionId returns nil when key not in data`() {
        let session = Session(id: SessionID(string: "test-session"), data: [:])

        let retrieved = session.sessionId

        #expect(retrieved == nil)
    }

    @Test
    func `get sessionId returns nil for malformed string`() {
        let session = Session(id: SessionID(string: "test-session"), data: [:])
        session.data[Session.sessionIdKey] = "not-a-valid-uuid"

        let retrieved = session.sessionId

        #expect(retrieved == nil)
    }

    @Test
    func `sessionId uses correct data key`() {
        #expect(Session.sessionIdKey == "_PassageSessionId")
    }
}

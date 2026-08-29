@testable import Passage
import Testing

@Suite(.tags(.unit))
struct `Transport Tests` {

    @Test
    func `browser case equals itself`() {
        #expect(Passage.Transport.browser == .browser)
    }

    @Test
    func `bearer case equals itself`() {
        #expect(Passage.Transport.bearer == .bearer)
    }

    @Test
    func `browser and bearer are distinct`() {
        #expect(Passage.Transport.browser != .bearer)
        #expect(Passage.Transport.bearer != .browser)
    }

    @Test
    func `is Sendable`() {
        let _: any Sendable = Passage.Transport.browser
        let _: any Sendable = Passage.Transport.bearer
    }
}

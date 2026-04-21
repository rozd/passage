import Testing
@testable import Passage

@Suite
struct `Views Style Tests` {

    // MARK: - Style Enum Tests

    @Test
    func `Style enum has all expected cases`() {
        let styles: [Passage.Views.Style] = [
            .neobrutalism,
            .neomorphism,
            .minimalism,
            .material
        ]

        #expect(styles.count == 4)
    }

    // MARK: - Template Suffix Tests

    @Test("Template suffix for each style", arguments: [
        (Passage.Views.Style.neobrutalism, "neobrutalism"),
        (Passage.Views.Style.neomorphism, "neomorphism"),
        (Passage.Views.Style.minimalism, "minimalism"),
        (Passage.Views.Style.material, "material")
    ])
    func templateSuffix(style: Passage.Views.Style, expectedSuffix: String) {
        #expect(style.templateSuffix == expectedSuffix)
    }

    // MARK: - Sendable Conformance Tests

    @Test
    func `Style conforms to Sendable`() {
        let style: any Sendable = Passage.Views.Style.neobrutalism
        #expect(style is Passage.Views.Style)
    }
}

import Testing
@testable import Passage

@Suite
struct `Views Theme Tests` {

    // MARK: - Theme Brightness Tests

    @Test
    func `Brightness enum cases`() {
        let brightnesses: [Passage.Views.Theme.Brightness] = [
            .light,
            .dark
        ]

        #expect(brightnesses.count == 2)
    }

    // MARK: - Theme Initialization Tests

    @Test
    func `Theme initialization with colors`() {
        let colors = Passage.Views.Theme.Colors.defaultLight
        let theme = Passage.Views.Theme(colors: colors)

        #expect(theme.colors.primary == colors.primary)
        #expect(theme.overrides.isEmpty)
    }

    @Test
    func `Theme initialization with overrides`() {
        let lightColors = Passage.Views.Theme.Colors.defaultLight
        let darkColors = Passage.Views.Theme.Colors.defaultDark

        let theme = Passage.Views.Theme(
            colors: lightColors,
            overrides: [
                .dark: .init(colors: darkColors)
            ]
        )

        #expect(theme.colors.primary == lightColors.primary)
        #expect(!theme.overrides.isEmpty)
    }

    // MARK: - Theme Resolution Tests

    @Test
    func `Theme resolves to base colors for light when no override`() {
        let colors = Passage.Views.Theme.Colors.defaultLight
        let theme = Passage.Views.Theme(colors: colors)

        let resolved = theme.colors(for: .light)

        #expect(resolved.primary == colors.primary)
    }

    @Test
    func `Theme resolves to override colors when available`() {
        let lightColors = Passage.Views.Theme.Colors.defaultLight
        let darkColors = Passage.Views.Theme.Colors.defaultDark

        let theme = Passage.Views.Theme(
            colors: lightColors,
            overrides: [
                .dark: .init(colors: darkColors)
            ]
        )

        let resolvedDark = theme.colors(for: .dark)

        #expect(resolvedDark.primary == darkColors.primary)
        #expect(resolvedDark.primary != lightColors.primary)
    }

    @Test
    func `Theme resolves to base colors when override not available`() {
        let colors = Passage.Views.Theme.Colors.defaultLight
        let theme = Passage.Views.Theme(colors: colors)

        let resolvedDark = theme.colors(for: .dark)

        // Should fall back to base colors
        #expect(resolvedDark.primary == colors.primary)
    }

    @Test
    func `Theme resolve method creates Resolved struct`() {
        let colors = Passage.Views.Theme.Colors.defaultLight
        let theme = Passage.Views.Theme(colors: colors)

        let resolved = theme.resolve(for: .light)

        #expect(resolved.colors.primary == colors.primary)
    }

    // MARK: - Default Theme Colors Tests

    @Test
    func `Default light theme has expected primary color`() {
        let colors = Passage.Views.Theme.Colors.defaultLight
        #expect(colors.primary == "#6200EE")
    }

    @Test
    func `Default dark theme has expected primary color`() {
        let colors = Passage.Views.Theme.Colors.defaultDark
        #expect(colors.primary == "#BB86FC")
    }

    @Test(arguments: [
        Passage.Views.Theme.Colors.defaultLight,
        Passage.Views.Theme.Colors.defaultDark,
        Passage.Views.Theme.Colors.oceanLight,
        Passage.Views.Theme.Colors.oceanDark,
        Passage.Views.Theme.Colors.forestLight,
        Passage.Views.Theme.Colors.forestDark
    ])
    func `All default themes have all required color properties`(colors: Passage.Views.Theme.Colors) {
        #expect(!colors.primary.isEmpty)
        #expect(!colors.onPrimary.isEmpty)
        #expect(!colors.secondary.isEmpty)
        #expect(!colors.onSecondary.isEmpty)
        #expect(!colors.surface.isEmpty)
        #expect(!colors.onSurface.isEmpty)
        #expect(!colors.onSurfaceVariant.isEmpty)
        #expect(!colors.background.isEmpty)
        #expect(!colors.onBackground.isEmpty)
        #expect(!colors.error.isEmpty)
        #expect(!colors.onError.isEmpty)
        #expect(!colors.warning.isEmpty)
        #expect(!colors.onWarning.isEmpty)
        #expect(!colors.success.isEmpty)
        #expect(!colors.onSuccess.isEmpty)
        #expect(!colors.outline.isEmpty)
    }

    @Test(arguments: [
        Passage.Views.Theme.Colors.defaultLight,
        Passage.Views.Theme.Colors.defaultDark
    ])
    func `All color values are valid hex codes`(colors: Passage.Views.Theme.Colors) {
        let allColors = [
            colors.primary, colors.onPrimary, colors.secondary, colors.onSecondary,
            colors.surface, colors.onSurface, colors.onSurfaceVariant,
            colors.background, colors.onBackground,
            colors.error, colors.onError,
            colors.warning, colors.onWarning,
            colors.success, colors.onSuccess,
            colors.outline
        ]

        for color in allColors {
            #expect(color.hasPrefix("#"))
            #expect(color.count == 7) // #RRGGBB format
        }
    }

    // MARK: - Theme Color Pairs Tests

    @Test
    func `Ocean theme has both light and dark variants`() {
        let light = Passage.Views.Theme.Colors.oceanLight
        let dark = Passage.Views.Theme.Colors.oceanDark

        #expect(light.primary != dark.primary)
        #expect(light.background != dark.background)
    }

    @Test
    func `Forest theme has both light and dark variants`() {
        let light = Passage.Views.Theme.Colors.forestLight
        let dark = Passage.Views.Theme.Colors.forestDark

        #expect(light.primary != dark.primary)
        #expect(light.background != dark.background)
    }

    @Test
    func `Sunset theme has both light and dark variants`() {
        let light = Passage.Views.Theme.Colors.sunsetLight
        let dark = Passage.Views.Theme.Colors.sunsetDark

        #expect(light.primary != dark.primary)
        #expect(light.background != dark.background)
    }

    // MARK: - Sendable Conformance Tests

    @Test
    func `Theme conforms to Sendable`() {
        let theme: any Sendable = Passage.Views.Theme(colors: .defaultLight)
        #expect(theme is Passage.Views.Theme)
    }

    @Test
    func `Theme.Colors conforms to Sendable`() {
        let colors: any Sendable = Passage.Views.Theme.Colors.defaultLight
        #expect(colors is Passage.Views.Theme.Colors)
    }

    @Test
    func `Theme.Brightness conforms to Sendable`() {
        let brightness: any Sendable = Passage.Views.Theme.Brightness.light
        #expect(brightness is Passage.Views.Theme.Brightness)
    }
}

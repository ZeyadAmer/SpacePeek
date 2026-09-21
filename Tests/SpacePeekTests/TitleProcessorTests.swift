import Testing
@testable import SpacePeek

@Suite("Title strategies")
struct TitleProcessorTests {
    private func preferences(
        default defaultStrategy: TitleStrategy = .folder,
        rules: [AppRule] = []
    ) -> Preferences {
        var prefs = Preferences()
        prefs.defaultStrategy = defaultStrategy
        prefs.appRules = rules
        return prefs
    }

    @Test("folder strategy keeps the project, file strategy keeps the file")
    func splitsOnSeparator() {
        let raw = "funbuzz — Preview ROADMAP.md"
        #expect(TitleProcessor.apply(strategy: .folder, to: raw) == "funbuzz")
        #expect(TitleProcessor.apply(strategy: .fileName, to: raw) == "Preview ROADMAP.md")
    }

    @Test("app name strategy reports the owning app, not the window title")
    func appNameStrategyUsesOwner() {
        #expect(TitleProcessor.apply(strategy: .appName, to: "✳ Space peek macOS 27", appName: "Warp") == "Warp")
    }

    @Test("app name strategy falls back to the title when the owner is unknown")
    func appNameStrategyFallsBack() {
        #expect(TitleProcessor.apply(strategy: .appName, to: "Desktop", appName: nil) == "Desktop")
    }

    @Test("a rule matches on the owning app even when the title never mentions it")
    func ruleMatchesOwningApp() {
        let prefs = preferences(rules: [AppRule(appName: "Warp", strategy: .appName)])
        let resolved = TitleProcessor.resolveStrategy(
            forRawTitle: "✳ Space peek macOS 27 upgrade",
            appName: "Warp",
            preferences: prefs
        )
        #expect(resolved == .appName)
    }

    @Test("rules for different apps stay independent")
    func rulesAreScopedPerApp() {
        let prefs = preferences(rules: [
            AppRule(appName: "Warp", strategy: .appName),
            AppRule(appName: "Antigravity", strategy: .folder)
        ])
        let warp = TitleProcessor.displayTitle(
            forRawTitle: "✳ Space peek macOS 27 upgrade",
            appName: "Warp",
            preferences: prefs
        )
        let ide = TitleProcessor.displayTitle(
            forRawTitle: "funbuzz — Preview ROADMAP.md",
            appName: "Antigravity IDE",
            preferences: prefs
        )
        #expect(warp == "Warp")
        #expect(ide == "funbuzz")
    }

    @Test("first matching rule wins")
    func firstRuleWins() {
        let prefs = preferences(rules: [
            AppRule(appName: "Chrome", strategy: .raw),
            AppRule(appName: "Chrome", strategy: .folder)
        ])
        #expect(TitleProcessor.resolveStrategy(forRawTitle: "Nawy — Chrome", preferences: prefs) == .raw)
    }

    @Test("titles are capped with an ellipsis")
    func truncatesLongTitles() {
        let long = "tg-aws-account-live — ecs-task-config.yaml"
        let result = TitleProcessor.truncate(long)
        #expect(result.count <= TitleProcessor.maxCharacters)
        #expect(result.hasSuffix("…"))
    }

    @Test("a per-space rename overrides the strategy result")
    func renameOverridesStrategy() {
        var prefs = preferences()
        prefs.spaceOverrides["funbuzz"] = SpaceOverride(customName: "Side project", strategy: nil)
        #expect(TitleProcessor.displayTitle(forRawTitle: "funbuzz — ROADMAP.md", preferences: prefs) == "Side project")
    }
}

@Suite("Mission Control space identifiers")
struct SpaceIdentifierTests {
    @Test("extracts the bundle id from a Mission Control space identifier", arguments: [
        ("dev.warp.Warp-Stable.space.129", "dev.warp.Warp-Stable"),
        ("com.google.Chrome.space.117", "com.google.Chrome"),
        ("com.apple.Notes.space.21", "com.apple.Notes")
    ])
    func parsesBundleIdentifier(identifier: String, expected: String) {
        #expect(ThumbnailScanner.bundleIdentifier(fromSpaceIdentifier: identifier) == expected)
    }

    @Test("rejects identifiers that are not space identifiers", arguments: [
        "mc.spaces.list", "mc.spaces.add", "com.google.Chrome.space.", "com.google.Chrome.space.abc", ".space.1"
    ])
    func rejectsNonSpaceIdentifiers(identifier: String) {
        #expect(ThumbnailScanner.bundleIdentifier(fromSpaceIdentifier: identifier) == nil)
    }
}

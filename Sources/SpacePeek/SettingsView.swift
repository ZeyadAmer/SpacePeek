import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var preferencesStore: PreferencesStore = .shared
    @ObservedObject var spacesStore: SpacesSnapshotStore = .shared
    @ObservedObject var fontImporter: FontImporter = .shared

    var body: some View {
        TabView {
            GeneralTab(preferences: $preferencesStore.preferences, fontImporter: fontImporter)
                .tabItem {
                    Label("General", systemImage: "slider.horizontal.3")
                }
            PerSpaceTab(preferences: $preferencesStore.preferences, snapshots: spacesStore.snapshots)
                .tabItem {
                    Label("Per-Space", systemImage: "rectangle.3.group")
                }
            AppRulesTab(preferences: $preferencesStore.preferences)
                .tabItem {
                    Label("App Rules", systemImage: "app.badge.checkmark")
                }
        }
        .frame(width: 620, height: 520)
    }
}

private struct GeneralTab: View {
    @Binding var preferences: Preferences
    @ObservedObject var fontImporter: FontImporter

    private static let builtInFonts: [String] = ["System", "SF Pro Text", "SF Mono", "Menlo", "Helvetica Neue", "Avenir Next"]

    private var allFonts: [String] {
        Self.builtInFonts + fontImporter.customFamilies
    }

    var body: some View {
        Form {
            Section("Title strategy") {
                Picker("Default", selection: $preferences.defaultStrategy) {
                    ForEach(TitleStrategy.allCases) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)

                Text("Splits titles like `Project — file.tsx` based on this rule. Override per app on the App Rules tab or per space on the Per-Space tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Label style") {
                HStack {
                    Picker("Font", selection: $preferences.labelStyle.fontName) {
                        ForEach(allFonts, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Button {
                        importFont()
                    } label: {
                        Label("Import…", systemImage: "square.and.arrow.down")
                    }
                }

                if !fontImporter.customFamilies.isEmpty {
                    DisclosureGroup("Custom fonts (\(fontImporter.customFamilies.count))") {
                        ForEach(fontImporter.customFamilies, id: \.self) { family in
                            HStack {
                                Text(family)
                                    .font(.custom(family, size: 13))
                                Spacer()
                                Button(role: .destructive) {
                                    fontImporter.remove(family: family)
                                    if preferences.labelStyle.fontName == family {
                                        preferences.labelStyle.fontName = "System"
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                HStack {
                    Text("Size")
                    Slider(value: $preferences.labelStyle.fontSize, in: 9...18, step: 1)
                    Text("\(Int(preferences.labelStyle.fontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }

                Toggle("Bold", isOn: $preferences.labelStyle.bold)
            }

            Section("Preview") {
                LabelPreview(style: preferences.labelStyle)
            }
        }
        .formStyle(.grouped)
    }

    private func importFont() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.font]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import font"
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let family = fontImporter.importFont(at: url) {
            preferences.labelStyle.fontName = family
        } else {
            let alert = NSAlert()
            alert.messageText = "Font import failed"
            alert.informativeText = "SpacePeek could not register that font. Make sure it is a valid .ttf, .otf, or .ttc file."
            alert.runModal()
        }
    }
}

private struct LabelPreview: View {
    let style: LabelStyle

    var body: some View {
        HStack(spacing: 24) {
            ForEach(["Desktop", "Claude", "Sales Portal"], id: \.self) { sample in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 80, height: 48)
                    Text(sample)
                        .font(.custom(style.fontName == "System" ? "SF Pro Text" : style.fontName, size: style.fontSize))
                        .fontWeight(style.bold ? .bold : .regular)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct PerSpaceTab: View {
    @Binding var preferences: Preferences
    let snapshots: [SpaceSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rename detected spaces. The match key is the post-strategy base name, so Chrome profile names or project folders stay stable as tabs and files change.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chrome tip")
                        .font(.caption).bold()
                    Text("Right-click an empty spot on Chrome's tab strip → **Name window…** → enter `Work`, `Personal`, etc. The macOS window title becomes the window name and stays put when you switch tabs. SpacePeek will pick it up automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.08)))
            .padding(.horizontal)

            if snapshots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Open Mission Control once to populate this list.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(snapshots) { snapshot in
                        PerSpaceRow(preferences: $preferences, snapshot: snapshot)
                    }
                }
            }
        }
    }
}

private struct PerSpaceRow: View {
    @Binding var preferences: Preferences
    let snapshot: SpaceSnapshot

    private var customName: Binding<String> {
        Binding<String>(
            get: { preferences.spaceOverrides[snapshot.id]?.customName ?? "" },
            set: { new in
                let trimmed = new.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    preferences.spaceOverrides.removeValue(forKey: snapshot.id)
                } else {
                    preferences.spaceOverrides[snapshot.id] = SpaceOverride(customName: trimmed, strategy: nil)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.id)
                    .font(.headline)
                Spacer()
                Text("Preview: \(TitleProcessor.displayTitle(forRawTitle: snapshot.rawTitle, preferences: preferences))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                TextField("Rename (optional)", text: customName)
                    .textFieldStyle(.roundedBorder)
            }
            Text("Raw: \(snapshot.rawTitle)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct AppRulesTab: View {
    @Binding var preferences: Preferences
    @State private var draftName: String = ""
    @State private var draftStrategy: TitleStrategy = .folder

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apply a strategy when a space title contains the given app name (case-insensitive). Rules are checked top to bottom; first match wins.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)

            HStack {
                TextField("App name (e.g. Cursor)", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $draftStrategy) {
                    ForEach(TitleStrategy.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .frame(width: 160)
                Button("Add") {
                    let trimmed = draftName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    PreferencesStore.shared.upsertRule(AppRule(appName: trimmed, strategy: draftStrategy))
                    draftName = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)

            if preferences.appRules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No rules yet. Add one above to override the default strategy per app.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(preferences.appRules) { rule in
                        AppRuleRow(rule: rule)
                    }
                }
            }
        }
    }
}

private struct AppRuleRow: View {
    let rule: AppRule

    @State private var name: String
    @State private var strategy: TitleStrategy

    init(rule: AppRule) {
        self.rule = rule
        _name = State(initialValue: rule.appName)
        _strategy = State(initialValue: rule.strategy)
    }

    var body: some View {
        HStack {
            TextField("App name", text: $name, onCommit: commit)
                .textFieldStyle(.roundedBorder)
            Picker("", selection: $strategy) {
                ForEach(TitleStrategy.allCases) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .frame(width: 160)
            .onChange(of: strategy) { _, _ in commit() }
            Button(role: .destructive) {
                PreferencesStore.shared.deleteRule(id: rule.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        PreferencesStore.shared.upsertRule(AppRule(id: rule.id, appName: trimmed, strategy: strategy))
    }
}

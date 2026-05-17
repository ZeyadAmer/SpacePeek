import AppKit
import Foundation

enum TitleStrategy: String, Codable, CaseIterable, Identifiable {
    case raw
    case folder
    case fileName
    case appProfile

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raw: return "Raw"
        case .folder: return "Folder name"
        case .fileName: return "File name"
        case .appProfile: return "App profile"
        }
    }
}

struct AppRule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var appName: String
    var strategy: TitleStrategy
}

struct SpaceOverride: Codable, Equatable {
    var customName: String?
    var strategy: TitleStrategy?
}

struct LabelStyle: Codable, Equatable {
    var fontName: String = "SF Pro Text"
    var fontSize: CGFloat = 21
    var bold: Bool = true

    func makeFont() -> NSFont {
        let weight: NSFont.Weight = bold ? .bold : .regular
        if fontName == "SF Pro Text" || fontName == "System" {
            return .systemFont(ofSize: fontSize, weight: weight)
        }
        let descriptor: NSFontDescriptor = {
            let base = NSFontDescriptor(name: fontName, size: fontSize)
            guard bold else { return base }
            return base.withSymbolicTraits([.bold])
        }()
        return NSFont(descriptor: descriptor, size: fontSize) ?? .systemFont(ofSize: fontSize, weight: weight)
    }
}

struct Preferences: Codable, Equatable {
    var defaultStrategy: TitleStrategy = .folder
    var spaceOverrides: [String: SpaceOverride] = [:]
    var appRules: [AppRule] = []
    var labelStyle: LabelStyle = LabelStyle()
}

final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()
    static let didChangeNotification = Notification.Name("SpacePeekPreferencesDidChange")

    private static let storageKey = "SpacePeek.Preferences.v1"

    @Published var preferences: Preferences {
        didSet {
            guard preferences != oldValue else { return }
            persist()
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    private init() {
        self.preferences = Self.load() ?? Preferences()
    }

    private static func load() -> Preferences? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(Preferences.self, from: data)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func setOverride(_ override: SpaceOverride?, for rawTitle: String) {
        var prefs = preferences
        if let override, override.customName != nil || override.strategy != nil {
            prefs.spaceOverrides[rawTitle] = override
        } else {
            prefs.spaceOverrides.removeValue(forKey: rawTitle)
        }
        preferences = prefs
    }

    func upsertRule(_ rule: AppRule) {
        var prefs = preferences
        if let idx = prefs.appRules.firstIndex(where: { $0.id == rule.id }) {
            prefs.appRules[idx] = rule
        } else {
            prefs.appRules.append(rule)
        }
        preferences = prefs
    }

    func deleteRule(id: UUID) {
        var prefs = preferences
        prefs.appRules.removeAll { $0.id == id }
        preferences = prefs
    }
}

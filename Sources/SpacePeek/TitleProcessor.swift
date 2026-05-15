import Foundation

enum TitleProcessor {
    static let maxCharacters = 18

    private static let separators: [String] = [" — ", " – ", " - ", " | "]

    static func displayTitle(forRawTitle raw: String, preferences: Preferences) -> String {
        let base = baseTitle(forRawTitle: raw, preferences: preferences)
        if let override = preferences.spaceOverrides[base], let custom = override.customName, !custom.isEmpty {
            return truncate(custom)
        }
        return truncate(base)
    }

    static func baseTitle(forRawTitle raw: String, preferences: Preferences) -> String {
        let strategy = resolveStrategy(forRawTitle: raw, preferences: preferences)
        return apply(strategy: strategy, to: raw)
    }

    static func resolveStrategy(forRawTitle raw: String, preferences: Preferences) -> TitleStrategy {
        let lower = raw.lowercased()
        for rule in preferences.appRules where !rule.appName.isEmpty {
            if lower.contains(rule.appName.lowercased()) {
                return rule.strategy
            }
        }
        return preferences.defaultStrategy
    }

    static func apply(strategy: TitleStrategy, to raw: String) -> String {
        switch strategy {
        case .raw:
            return raw
        case .folder:
            return firstSegment(of: raw)
        case .fileName:
            return lastSegment(of: raw)
        case .appProfile:
            return profileSegment(of: raw)
        }
    }

    static func truncate(_ value: String) -> String {
        guard value.count > maxCharacters else { return value }
        let cutoff = value.index(value.startIndex, offsetBy: maxCharacters - 1)
        return String(value[..<cutoff]).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func firstSegment(of raw: String) -> String {
        for separator in separators {
            if let range = raw.range(of: separator) {
                return String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        return raw
    }

    private static func lastSegment(of raw: String) -> String {
        for separator in separators {
            if let range = raw.range(of: separator, options: .backwards) {
                return String(raw[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return raw
    }

    private static let appSuffixes: [String] = [
        "Google Chrome",
        "Chrome",
        "Chrome Canary",
        "Safari",
        "Firefox",
        "Firefox Developer Edition",
        "Microsoft Edge",
        "Edge",
        "Brave",
        "Brave Browser",
        "Arc",
        "Vivaldi",
        "Opera"
    ]

    private static func profileSegment(of raw: String) -> String {
        var parts = splitOnSeparators(raw)
        if let last = parts.last, appSuffixes.contains(last) {
            parts.removeLast()
        }
        guard !parts.isEmpty else { return raw }
        if parts.count == 1 {
            return parts[0]
        }
        return parts.last ?? raw
    }

    private static func splitOnSeparators(_ value: String) -> [String] {
        var current = [value]
        for separator in separators {
            current = current.flatMap { $0.components(separatedBy: separator) }
        }
        return current.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

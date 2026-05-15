import AppKit
import CoreText

final class FontImporter: ObservableObject {
    static let shared = FontImporter()

    @Published private(set) var customFamilies: [String] = []

    private static let directoryName = "Fonts"

    private init() {
        registerAll()
        refresh()
    }

    static var fontsDirectory: URL? {
        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
        else { return nil }
        let dir = appSupport.appendingPathComponent("SpacePeek").appendingPathComponent(directoryName)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    @discardableResult
    func importFont(at sourceURL: URL) -> String? {
        guard let dir = Self.fontsDirectory else { return nil }
        let destURL = dir.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            return nil
        }
        guard register(url: destURL) else {
            try? FileManager.default.removeItem(at: destURL)
            return nil
        }
        let family = Self.fontFamilyName(from: destURL)
        refresh()
        return family
    }

    func remove(family: String) {
        guard let dir = Self.fontsDirectory else { return }
        guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in urls where Self.fontFamilyName(from: url) == family {
            var errorRef: Unmanaged<CFError>?
            CTFontManagerUnregisterFontsForURL(url as CFURL, .process, &errorRef)
            try? FileManager.default.removeItem(at: url)
        }
        refresh()
    }

    func registerAll() {
        guard let dir = Self.fontsDirectory else { return }
        guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in urls where ["ttf", "otf", "ttc"].contains(url.pathExtension.lowercased()) {
            _ = register(url: url)
        }
    }

    func refresh() {
        guard let dir = Self.fontsDirectory else {
            customFamilies = []
            return
        }
        guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            customFamilies = []
            return
        }
        let names = urls.compactMap { Self.fontFamilyName(from: $0) }
        let unique = Array(Set(names)).sorted()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.customFamilies != unique {
                self.customFamilies = unique
            }
        }
    }

    private func register(url: URL) -> Bool {
        var errorRef: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef)
        if !success, let error = errorRef?.takeRetainedValue() {
            let code = CFErrorGetCode(error)
            if code == CTFontManagerError.alreadyRegistered.rawValue {
                return true
            }
            return false
        }
        return success
    }

    private static func fontFamilyName(from url: URL) -> String? {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let first = descriptors.first
        else { return nil }
        return CTFontDescriptorCopyAttribute(first, kCTFontFamilyNameAttribute) as? String
    }
}

import AppKit
import ApplicationServices

enum ThumbnailScanner {
    static func dockElement() -> AXUIElement? {
        let workspace = NSWorkspace.shared
        guard let dock = workspace.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
            return nil
        }
        return AXUIElementCreateApplication(dock.processIdentifier)
    }

    static func scan() -> [Thumbnail] {
        guard let dock = dockElement() else {
            FileHandle.standardError.write(Data("[WL] no dock element\n".utf8))
            return []
        }

        guard let mc = findMissionControlRoot(in: dock) else { return [] }
        guard let spacesList = findSpacesList(in: mc) else { return [] }

        let children = copyChildren(of: spacesList)
        var collected: [Thumbnail] = []
        for (index, child) in children.enumerated() {
            guard let thumb = spaceTile(from: child, index: index) else { continue }
            collected.append(thumb)
        }

        if ProcessInfo.processInfo.environment["WL_DEBUG"] != nil {
            let titles = collected.map { $0.title }.joined(separator: " | ")
            FileHandle.standardError.write(Data("[WL] spaces count=\(collected.count) titles=[\(titles)]\n".utf8))
        }
        return collected
    }

    private static func findMissionControlRoot(in dock: AXUIElement) -> AXUIElement? {
        for child in copyChildren(of: dock) {
            guard let role = copyAttribute(child, kAXRoleAttribute) as? String, role == kAXGroupRole as String else {
                continue
            }
            if let id = copyAttribute(child, kAXIdentifierAttribute) as? String, id == "mc" {
                return child
            }
        }
        return nil
    }

    private static func findSpacesList(in mc: AXUIElement) -> AXUIElement? {
        if let id = copyAttribute(mc, kAXIdentifierAttribute) as? String, id == "mc.spaces.list" {
            return mc
        }
        for child in copyChildren(of: mc) {
            if let found = findSpacesList(in: child) {
                return found
            }
        }
        return nil
    }

    private static func spaceTile(from element: AXUIElement, index: Int) -> Thumbnail? {
        let role = (copyAttribute(element, kAXRoleAttribute) as? String) ?? ""
        guard role == kAXButtonRole as String else { return nil }

        if let id = copyAttribute(element, kAXIdentifierAttribute) as? String, id == "mc.spaces.add" {
            return nil
        }

        let rawTitleAttr = (copyAttribute(element, kAXTitleAttribute) as? String) ?? ""
        let rawDesc = (copyAttribute(element, kAXDescriptionAttribute) as? String) ?? ""

        let rawTitle = pickTitle(rawTitle: rawTitleAttr, rawDesc: rawDesc)
        guard !rawTitle.isEmpty else { return nil }

        guard let frame = frame(of: element) else { return nil }
        guard frame.width >= 20, frame.height >= 20 else { return nil }

        let preferences = PreferencesStore.shared.preferences
        let displayTitle = TitleProcessor.displayTitle(forRawTitle: rawTitle, preferences: preferences)

        let id = "space.\(index).\(Int(frame.origin.x))_\(Int(frame.origin.y))_\(rawTitle)"
        return Thumbnail(id: id, frame: frame, rawTitle: rawTitle, title: displayTitle)
    }

    private static func pickTitle(rawTitle: String, rawDesc: String) -> String {
        let trimmedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200E}", with: "")
        if !trimmedTitle.isEmpty { return trimmedTitle }

        let prefixes = ["exit to full screen ", "exit to "]
        let trimmedDesc = rawDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in prefixes {
            if trimmedDesc.hasPrefix(prefix) {
                return String(trimmedDesc.dropFirst(prefix.count))
            }
        }
        return trimmedDesc
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard
            let positionValue = copyAttribute(element, kAXPositionAttribute),
            let sizeValue = copyAttribute(element, kAXSizeAttribute)
        else { return nil }

        var origin = CGPoint.zero
        var size = CGSize.zero
        let positionRef = positionValue as! AXValue
        let sizeRef = sizeValue as! AXValue
        guard AXValueGetType(positionRef) == .cgPoint, AXValueGetType(sizeRef) == .cgSize else { return nil }
        AXValueGetValue(positionRef, .cgPoint, &origin)
        AXValueGetValue(sizeRef, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }

    private static func copyChildren(of element: AXUIElement) -> [AXUIElement] {
        guard let raw = copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return [] }
        return raw
    }

    private static func copyAttribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard result == .success else { return nil }
        return value
    }
}

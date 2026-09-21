import AppKit
import ApplicationServices

enum ThumbnailScanner {
    /// Bundle IDs that have hosted Mission Control's accessibility tree.
    /// macOS 26 and earlier: Dock (root group `mc`).
    /// macOS 27: WindowManager (root group `mc.display`, one per screen).
    private static let windowManagerBundleID = "com.apple.WindowManager"
    private static let missionControlHostBundleIDs = ["com.apple.dock", windowManagerBundleID]
    private static let missionControlRootIdentifiers: Set<String> = ["mc", "mc.display"]
    private static let spacesListIdentifier = "mc.spaces.list"
    private static let maxSpacesListSearchDepth = 6
    private static let minimumTileSide: CGFloat = 20

    private static func missionControlHostApplications() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { missionControlHostBundleIDs.contains($0.bundleIdentifier ?? "") }
    }

    static func missionControlHosts() -> [AXUIElement] {
        missionControlHostApplications().map { AXUIElementCreateApplication($0.processIdentifier) }
    }

    static func scan() -> [Thumbnail] {
        let hostApps = missionControlHostApplications()
        guard !hostApps.isEmpty else {
            logDiagnostic("[WL] no Mission Control host process\n")
            return []
        }

        let strips = spacesStrips(in: hostApps)
        guard !strips.isEmpty else { return [] }

        let renderedRows = renderedTileRows(hostPIDs: Set(hostApps.map { $0.processIdentifier }))
        let ownersByTitle = ownerAppNamesByTitle(in: hostApps)
        var collected: [Thumbnail] = []
        var index = 0
        for strip in strips {
            var tiles: [Thumbnail] = []
            for child in copyChildren(of: strip.element) {
                defer { index += 1 }
                guard let thumb = spaceTile(from: child, index: index, ownersByTitle: ownersByTitle) else { continue }
                tiles.append(thumb)
            }
            if let aligned = alignToRenderedTiles(tiles, rows: renderedRows) {
                collected.append(contentsOf: aligned)
            } else if !strip.requiresRenderedGeometry {
                collected.append(contentsOf: tiles)
            }
            // Otherwise the strip is mid-animation (macOS 27 magnifies the hovered tile, which
            // splits the tiles into several rows) and macOS draws its own names. Emitting nothing
            // hides our labels until the strip settles, instead of duplicating Apple's at stale
            // AX coordinates.
        }
        collected = dedupeByRawTitle(collected)

        if ProcessInfo.processInfo.environment["WL_DEBUG"] != nil {
            let titles = collected.map { $0.title }.joined(separator: " | ")
            let first = collected.first.map { "\(Int($0.frame.minX)),\(Int($0.frame.minY)) \(Int($0.frame.width))x\(Int($0.frame.height))" } ?? "-"
            let rowSummary = renderedRows
                .map { "\($0.count)@y=\(Int($0.first?.minY ?? 0))/\(Int($0.first?.width ?? 0))x\(Int($0.first?.height ?? 0))" }
                .joined(separator: " ")
            logDiagnostic("[WL] spaces count=\(collected.count) tile0=\(first) rows=[\(rowSummary)] titles=[\(titles)]\n")
        }
        return collected
    }

    /// macOS 27 reports strip tiles at AX frames that do not match where they render — a constant
    /// vertical offset plus a horizontal drift that grows across the strip. The window server's own
    /// bounds for those same tiles are correct, so geometry comes from there and AX supplies only
    /// the titles. Returns rows of equally-sized sibling windows, each sorted left to right.
    private static func renderedTileRows(hostPIDs: Set<pid_t>) -> [[CGRect]] {
        guard
            let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { return [] }

        let widestScreen = NSScreen.screens.map { $0.frame.width }.max() ?? 0
        var rows: [String: [CGRect]] = [:]
        for info in infos {
            guard
                let pid = info[kCGWindowOwnerPID as String] as? pid_t, hostPIDs.contains(pid),
                let layer = info[kCGWindowLayer as String] as? Int, layer > 0,
                let boundsDict = info[kCGWindowBounds as String],
                let rect = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary)
            else { continue }
            // Tiles are small; skip the strip backdrop and other full-width panels.
            guard rect.width >= minimumTileSide, rect.height >= minimumTileSide else { continue }
            guard widestScreen == 0 || rect.width < widestScreen / 2 else { continue }
            let key = "\(Int(rect.origin.y.rounded()))|\(Int(rect.height.rounded()))"
            rows[key, default: []].append(rect)
        }
        return rows.values.map { $0.sorted { $0.minX < $1.minX } }
    }

    /// Swaps AX frames for the matching rendered bounds, or nil when no row of sibling windows
    /// matches the tile count — meaning the strip is animating and its geometry cannot be trusted.
    private static func alignToRenderedTiles(_ tiles: [Thumbnail], rows: [[CGRect]]) -> [Thumbnail]? {
        guard !tiles.isEmpty else { return tiles }
        let candidates = rows.filter { $0.count == tiles.count }
        guard !candidates.isEmpty else { return nil }

        let ordered = tiles.sorted { $0.frame.minX < $1.frame.minX }
        guard let axLeftEdge = ordered.first?.frame.minX else { return nil }
        guard let row = candidates.min(by: {
            abs(($0.first?.minX ?? 0) - axLeftEdge) < abs(($1.first?.minX ?? 0) - axLeftEdge)
        }) else { return nil }

        var renderedByID: [String: CGRect] = [:]
        for (tile, rect) in zip(ordered, row) {
            renderedByID[tile.id] = rect
        }
        return tiles.map { tile in
            guard let rect = renderedByID[tile.id] else { return tile }
            return Thumbnail(id: tile.id, frame: rect, rawTitle: tile.rawTitle, title: tile.title, appName: tile.appName)
        }
    }

    /// Mission Control's window grid identifies each space's window as `<bundle id>.space.<number>`,
    /// which is the only place the owning app is exposed — the strip tiles carry just a window title.
    /// Maps window title to a human-readable app name.
    private static func ownerAppNamesByTitle(in hostApps: [NSRunningApplication]) -> [String: String] {
        var owners: [String: String] = [:]
        for app in hostApps {
            let host = AXUIElementCreateApplication(app.processIdentifier)
            for root in copyChildren(of: host) {
                guard
                    let rootID = copyAttribute(root, kAXIdentifierAttribute) as? String,
                    missionControlRootIdentifiers.contains(rootID)
                else { continue }
                for child in copyChildren(of: root) {
                    guard
                        let identifier = copyAttribute(child, kAXIdentifierAttribute) as? String,
                        let bundleID = bundleIdentifier(fromSpaceIdentifier: identifier),
                        let title = copyAttribute(child, kAXTitleAttribute) as? String,
                        !title.isEmpty
                    else { continue }
                    owners[title] = appName(forBundleIdentifier: bundleID)
                }
            }
        }
        return owners
    }

    /// `com.google.Chrome.space.117` -> `com.google.Chrome`
    static func bundleIdentifier(fromSpaceIdentifier identifier: String) -> String? {
        guard let range = identifier.range(of: ".space.", options: .backwards) else { return nil }
        let suffix = identifier[range.upperBound...]
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isNumber }) else { return nil }
        let bundleID = String(identifier[..<range.lowerBound])
        return bundleID.isEmpty ? nil : bundleID
    }

    private static var appNameCache: [String: String] = [:]

    private static func appName(forBundleIdentifier bundleID: String) -> String {
        if let cached = appNameCache[bundleID] { return cached }
        let resolved = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .compactMap { $0.localizedName }
            .first
            ?? bundleID.components(separatedBy: ".").last
            ?? bundleID
        appNameCache[bundleID] = resolved
        return resolved
    }

    private struct SpacesStrip {
        let element: AXUIElement
        /// macOS 27 reports unusable AX frames, so its strips must be positioned from window-server
        /// bounds. Older releases report correct AX frames and need no such fallback.
        let requiresRenderedGeometry: Bool
    }

    /// Every spaces strip currently on screen — one per display, empty when Mission Control is closed.
    private static func spacesStrips(in hostApps: [NSRunningApplication]) -> [SpacesStrip] {
        var strips: [SpacesStrip] = []
        for app in hostApps {
            let host = AXUIElementCreateApplication(app.processIdentifier)
            let needsRendered = app.bundleIdentifier == windowManagerBundleID
            var lists: [AXUIElement] = []
            for child in copyChildren(of: host) {
                guard
                    let id = copyAttribute(child, kAXIdentifierAttribute) as? String,
                    missionControlRootIdentifiers.contains(id)
                else { continue }
                collectSpacesLists(in: child, depth: 0, into: &lists)
            }
            strips.append(contentsOf: lists.map { SpacesStrip(element: $0, requiresRenderedGeometry: needsRendered) })
        }
        return strips
    }

    private static func collectSpacesLists(in element: AXUIElement, depth: Int, into lists: inout [AXUIElement]) {
        guard depth <= maxSpacesListSearchDepth else { return }
        if let id = copyAttribute(element, kAXIdentifierAttribute) as? String, id == spacesListIdentifier {
            lists.append(element)
            return
        }
        for child in copyChildren(of: element) {
            collectSpacesLists(in: child, depth: depth + 1, into: &lists)
        }
    }

    private static func spaceTile(from element: AXUIElement, index: Int, ownersByTitle: [String: String]) -> Thumbnail? {
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
        guard frame.width >= minimumTileSide, frame.height >= minimumTileSide else { return nil }

        let preferences = PreferencesStore.shared.preferences
        let appName = ownersByTitle[rawTitle]
        let displayTitle = TitleProcessor.displayTitle(forRawTitle: rawTitle, appName: appName, preferences: preferences)

        let id = "space.\(index).\(Int(frame.origin.x))_\(Int(frame.origin.y))_\(rawTitle)"
        return Thumbnail(id: id, frame: frame, rawTitle: rawTitle, title: displayTitle, appName: appName)
    }

    private static func dedupeByRawTitle(_ thumbs: [Thumbnail]) -> [Thumbnail] {
        var bestByTitle: [String: Thumbnail] = [:]
        var order: [String] = []
        for thumb in thumbs {
            let key = thumb.rawTitle
            if let existing = bestByTitle[key] {
                let existingArea = existing.frame.width * existing.frame.height
                let newArea = thumb.frame.width * thumb.frame.height
                if newArea > existingArea {
                    bestByTitle[key] = thumb
                }
            } else {
                bestByTitle[key] = thumb
                order.append(key)
            }
        }
        return order.compactMap { bestByTitle[$0] }
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

// MARK: - Diagnostics

extension ThumbnailScanner {
    /// Dumps the accessibility tree of every Mission Control host process.
    /// Enabled with SPACEPEEK_AXDUMP=1; output goes to stderr and
    /// ~/Library/Logs/SpacePeek-axdump.log so it survives `open -a`.
    /// Apple moves this tree between processes across macOS releases — this is how you find it again.
    static func dumpAccessibilityTree(maxDepth: Int = 8) {
        var out = "[AXDUMP] begin trusted=\(isAccessibilityTrusted())\n"
        for host in missionControlHosts() {
            dumpElement(host, depth: 0, maxDepth: maxDepth, into: &out)
        }
        out += "[AXDUMP] end\n"
        logDiagnostic(out)
    }

    /// Dumps on-screen window layers for the Mission Control hosts and SpacePeek itself.
    /// Tells us whether our overlay level is actually above Mission Control's compositing layer.
    static func dumpWindowLayers() {
        guard let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return }
        var out = "[LAYERS] begin\n"
        for info in infos {
            let owner = (info[kCGWindowOwnerName as String] as? String) ?? "?"
            guard ["Dock", "WindowManager", "SpacePeek"].contains(owner) else { continue }
            let layer = (info[kCGWindowLayer as String] as? Int) ?? 0
            let name = (info[kCGWindowName as String] as? String) ?? ""
            let alpha = (info[kCGWindowAlpha as String] as? Double) ?? -1
            let bounds = (info[kCGWindowBounds as String] as? [String: Any]) ?? [:]
            let x = (bounds["X"] as? Double) ?? 0, y = (bounds["Y"] as? Double) ?? 0
            let w = (bounds["Width"] as? Double) ?? 0, h = (bounds["Height"] as? Double) ?? 0
            out += "  owner=\(owner) layer=\(layer) alpha=\(alpha) name='\(name)' (\(Int(x)),\(Int(y)) \(Int(w))x\(Int(h)))\n"
        }
        out += "[LAYERS] end\n"
        logDiagnostic(out)
    }

    private static func dumpElement(_ element: AXUIElement, depth: Int, maxDepth: Int, into out: inout String) {
        guard depth <= maxDepth else { return }
        let role = (copyAttribute(element, kAXRoleAttribute) as? String) ?? "?"
        let identifier = (copyAttribute(element, kAXIdentifierAttribute) as? String) ?? ""
        let title = (copyAttribute(element, kAXTitleAttribute) as? String) ?? ""
        let desc = (copyAttribute(element, kAXDescriptionAttribute) as? String) ?? ""
        let children = copyChildren(of: element)
        let rect = frame(of: element).map { "(\(Int($0.origin.x)),\(Int($0.origin.y)) \(Int($0.width))x\(Int($0.height)))" } ?? "-"
        out += "\(String(repeating: "  ", count: depth))\(role) id='\(identifier)' title='\(title)' desc='\(desc)' \(rect) kids=\(children.count)\n"
        for child in children {
            dumpElement(child, depth: depth + 1, maxDepth: maxDepth, into: &out)
        }
    }

    /// Writes to stderr and to ~/Library/Logs/SpacePeek-axdump.log, which survives `open -a`.
    static func logDiagnostic(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
        appendToLogFile(text)
    }

    private static func appendToLogFile(_ text: String) {
        let path = NSHomeDirectory() + "/Library/Logs/SpacePeek-axdump.log"
        guard let handle = FileHandle(forWritingAtPath: path) else {
            try? text.write(toFile: path, atomically: true, encoding: .utf8)
            return
        }
        handle.seekToEndOfFile()
        handle.write(Data(text.utf8))
        try? handle.close()
    }
}

import AppKit

final class LabelOverlayController {
    private struct Entry {
        let window: NSWindow
        let labelFrame: NSRect
        let tileScreenFrame: NSRect
        let title: String
    }

    private var entries: [String: Entry] = [:]
    private var orderedIDs: [String] = []
    private(set) var stripBand: NSRect = .zero
    private var labelsHidden = false
    private var lastInStrip = false
    private var pendingShowWork: DispatchWorkItem?
    private var mouseTimer: Timer?
    private var stripCoverWindow: NSWindow?
    private let stripCoverHeight: CGFloat = 36
    private let stripCoverPaddingX: CGFloat = 24
    private let compactTileHeightRatio: CGFloat = 0.06
    private let coverBandMaxSpaces = 11
    private var isCompactLayout = false
    private var useCoverBand = false
    var onStripLeave: (() -> Void)?

    func isMouseInStripBand() -> Bool {
        guard stripBand != .zero else { return false }
        let mouse = NSEvent.mouseLocation
        return stripBand.contains(mouse) || mouse.y >= stripBand.minY
    }

    init() {
        startMouseTracking()
    }

    deinit {
        mouseTimer?.invalidate()
    }

    func show(thumbnails: [Thumbnail]) {
        sync(to: thumbnails)
    }

    func update(thumbnails: [Thumbnail]) {
        sync(to: thumbnails)
    }

    func hide() {
        pendingShowWork?.cancel()
        pendingShowWork = nil
        for entry in entries.values {
            entry.window.orderOut(nil)
        }
        entries.removeAll()
        orderedIDs.removeAll()
        stripCoverWindow?.orderOut(nil)
        stripCoverWindow = nil
        stripBand = .zero
        labelsHidden = false
        lastInStrip = false
        isCompactLayout = false
        useCoverBand = false
    }

    private func sync(to thumbnails: [Thumbnail]) {
        let incomingIDs = Set(thumbnails.map { $0.id })
        for (id, entry) in entries where !incomingIDs.contains(id) {
            entry.window.orderOut(nil)
            entries.removeValue(forKey: id)
        }
        orderedIDs = thumbnails.map { $0.id }

        let screenHeight = NSScreen.main?.frame.height ?? 900
        let maxTileHeight = thumbnails.map { $0.frame.height }.max() ?? 0
        isCompactLayout = maxTileHeight > 0 && maxTileHeight < screenHeight * compactTileHeightRatio
        useCoverBand = !isCompactLayout && thumbnails.count < coverBandMaxSpaces

        var union: NSRect = .null
        for thumbnail in thumbnails {
            let tileScreenFrame = convertToScreenCoords(thumbnail.frame)
            union = union.isNull ? tileScreenFrame : union.union(tileScreenFrame)
            let labelFrame = labelRect(for: tileScreenFrame, title: thumbnail.title, existing: entries[thumbnail.id])

            if let existing = entries[thumbnail.id] {
                existing.window.contentView = LabelView(title: thumbnail.title)
                if existing.labelFrame != labelFrame {
                    existing.window.setFrame(labelFrame, display: false)
                }
                if isCompactLayout {
                    existing.window.orderOut(nil)
                }
                entries[thumbnail.id] = Entry(
                    window: existing.window,
                    labelFrame: labelFrame,
                    tileScreenFrame: tileScreenFrame,
                    title: thumbnail.title
                )
            } else {
                let window = makeWindow()
                window.contentView = LabelView(title: thumbnail.title)
                window.setFrame(labelFrame, display: false)
                if !labelsHidden && !isCompactLayout {
                    window.orderFrontRegardless()
                }
                entries[thumbnail.id] = Entry(
                    window: window,
                    labelFrame: labelFrame,
                    tileScreenFrame: tileScreenFrame,
                    title: thumbnail.title
                )
            }
        }

        stripBand = union.isNull ? .zero : union.insetBy(dx: -16, dy: -16)

        if union.isNull || !useCoverBand {
            stripCoverWindow?.orderOut(nil)
            stripCoverWindow = nil
        } else {
            let screenFrame = NSScreen.main?.frame ?? union
            let coverFrame = NSRect(
                x: screenFrame.minX,
                y: union.minY - stripCoverHeight,
                width: screenFrame.width,
                height: stripCoverHeight
            )
            let cover = stripCoverWindow ?? makeStripCoverWindow()
            cover.setFrame(coverFrame, display: false)
            stripCoverWindow = cover
            if !labelsHidden {
                cover.orderFrontRegardless()
                for entry in entries.values {
                    entry.window.orderFrontRegardless()
                }
            }
        }
    }

    private func startMouseTracking() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.applyHoverState()
        }
        RunLoop.main.add(timer, forMode: .common)
        mouseTimer = timer
    }

    private func applyHoverState() {
        guard !entries.isEmpty, stripBand != .zero else { return }
        if useCoverBand { return }
        let mouse = NSEvent.mouseLocation
        let inStrip = stripBand.contains(mouse) || mouse.y >= stripBand.minY
        guard inStrip != lastInStrip else { return }
        lastInStrip = inStrip

        pendingShowWork?.cancel()
        pendingShowWork = nil

        if inStrip {
            if !labelsHidden {
                labelsHidden = true
                stripCoverWindow?.orderOut(nil)
                for entry in entries.values {
                    entry.window.orderOut(nil)
                }
            }
        } else {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.onStripLeave?()
                self.labelsHidden = false
                if !self.isCompactLayout {
                    if self.useCoverBand {
                        self.stripCoverWindow?.orderFrontRegardless()
                    }
                    for entry in self.entries.values {
                        entry.window.orderFrontRegardless()
                    }
                }
                self.pendingShowWork = nil
            }
            pendingShowWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
    }

    private func labelRect(for tile: NSRect, title: String, existing: Entry?) -> NSRect {
        let probe = existing?.window.contentView as? LabelView ?? LabelView(title: title)
        let intrinsic = probe.intrinsicContentSize
        let labelWidth: CGFloat = min(LabelView.maxWidth, max(intrinsic.width, 40))
        let labelHeight: CGFloat = max(intrinsic.height, 16)
        let originX = tile.midX - labelWidth / 2
        let originY = tile.minY - labelHeight - 8
        return NSRect(x: originX, y: originY, width: labelWidth, height: labelHeight)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        let shielded = Int(CGShieldingWindowLevel())
        window.level = NSWindow.Level(rawValue: max(shielded + 10, Int(CGWindowLevelForKey(.maximumWindow))))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle, .transient]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        return window
    }

    private func makeStripCoverWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        let shielded = Int(CGShieldingWindowLevel())
        window.level = NSWindow.Level(rawValue: shielded + 9)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle, .transient]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false

        let host = NSView()
        host.wantsLayer = true
        host.autoresizingMask = [.width, .height]
        if let layer = host.layer {
            layer.masksToBounds = false
            let gradient = CAGradientLayer()
            gradient.colors = [
                NSColor(calibratedWhite: 0.06, alpha: 0.0).cgColor,
                NSColor(calibratedWhite: 0.06, alpha: 1.0).cgColor,
                NSColor(calibratedWhite: 0.06, alpha: 1.0).cgColor,
                NSColor(calibratedWhite: 0.06, alpha: 0.0).cgColor
            ]
            gradient.locations = [0.0, 0.15, 0.85, 1.0]
            gradient.startPoint = CGPoint(x: 0.5, y: 1.0)
            gradient.endPoint = CGPoint(x: 0.5, y: 0.0)
            gradient.frame = host.bounds
            gradient.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer.addSublayer(gradient)
        }
        window.contentView = host
        return window
    }

    private func convertToScreenCoords(_ axFrame: CGRect) -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else { return axFrame }
        let primaryHeight = primaryScreen.frame.height
        let flippedY = primaryHeight - axFrame.origin.y - axFrame.height
        return CGRect(x: axFrame.origin.x, y: flippedY, width: axFrame.width, height: axFrame.height)
    }
}

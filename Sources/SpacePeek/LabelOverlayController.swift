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
        stripBand = .zero
        labelsHidden = false
        lastInStrip = false
    }

    private func sync(to thumbnails: [Thumbnail]) {
        let incomingIDs = Set(thumbnails.map { $0.id })
        for (id, entry) in entries where !incomingIDs.contains(id) {
            entry.window.orderOut(nil)
            entries.removeValue(forKey: id)
        }
        orderedIDs = thumbnails.map { $0.id }

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
                if !labelsHidden {
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
        let mouse = NSEvent.mouseLocation
        let inStrip = stripBand.contains(mouse) || mouse.y >= stripBand.minY
        guard inStrip != lastInStrip else { return }
        lastInStrip = inStrip

        pendingShowWork?.cancel()
        pendingShowWork = nil

        if inStrip {
            if !labelsHidden {
                labelsHidden = true
                for entry in entries.values {
                    entry.window.orderOut(nil)
                }
            }
        } else {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.onStripLeave?()
                self.labelsHidden = false
                for entry in self.entries.values {
                    entry.window.orderFrontRegardless()
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
        let originY = tile.minY - labelHeight - 2
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

    private func convertToScreenCoords(_ axFrame: CGRect) -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else { return axFrame }
        let primaryHeight = primaryScreen.frame.height
        let flippedY = primaryHeight - axFrame.origin.y - axFrame.height
        return CGRect(x: axFrame.origin.x, y: flippedY, width: axFrame.width, height: axFrame.height)
    }
}

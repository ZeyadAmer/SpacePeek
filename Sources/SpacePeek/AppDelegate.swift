import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var watcher: MissionControlWatcher?
    private var overlayController: LabelOverlayController?
    private var accessibilityPollTimer: Timer?
    private var accessibilityAlertOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = FontImporter.shared
        installStatusItem()
        evaluateAccessibility(promptIfMissing: true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesChange),
            name: PreferencesStore.didChangeNotification,
            object: nil
        )
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let icon = NSImage(systemSymbolName: "captions.bubble", accessibilityDescription: "SpacePeek") {
            icon.isTemplate = true
            item.button?.image = icon
        } else {
            item.button?.title = "SP"
        }
        item.button?.toolTip = "SpacePeek"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Recheck Permissions", action: #selector(recheckPermissions), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Force Scan Now", action: #selector(forceScan), keyEquivalent: "s"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SpacePeek", action: #selector(quit), keyEquivalent: "q"))
        for entry in menu.items { entry.target = self }
        item.menu = menu
        statusItem = item
    }

    private func startWatching() {
        guard watcher == nil else { return }
        let controller = LabelOverlayController()
        overlayController = controller

        let watcher = MissionControlWatcher(
            onShow: { [weak controller] thumbnails in
                SpacesSnapshotStore.shared.update(from: thumbnails)
                controller?.show(thumbnails: thumbnails)
            },
            onHide: { [weak controller] in
                controller?.hide()
            },
            onUpdate: { [weak controller] thumbnails in
                SpacesSnapshotStore.shared.update(from: thumbnails)
                controller?.update(thumbnails: thumbnails)
            },
            shouldPauseRefresh: { [weak controller] in
                controller?.isMouseInStripBand() ?? false
            }
        )
        controller.onStripLeave = { [weak watcher] in
            watcher?.scanOnce()
        }
        watcher.start()
        self.watcher = watcher
    }

    /// Single entry point for permission state. If granted, start watching and stop polling.
    /// If not granted, show one alert at most and poll silently until the user grants access.
    private func evaluateAccessibility(promptIfMissing: Bool) {
        if isAccessibilityTrusted(prompt: false) {
            stopAccessibilityPolling()
            startWatching()
            return
        }
        // Trigger the macOS system prompt only once per launch attempt.
        if promptIfMissing {
            _ = isAccessibilityTrusted(prompt: true)
        }
        presentAccessibilityAlertIfNeeded()
        startAccessibilityPolling()
    }

    private func startAccessibilityPolling() {
        guard accessibilityPollTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if isAccessibilityTrusted(prompt: false) {
                self.stopAccessibilityPolling()
                self.startWatching()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        accessibilityPollTimer = timer
    }

    private func stopAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
    }

    private func presentAccessibilityAlertIfNeeded() {
        guard !accessibilityAlertOpen else { return }
        accessibilityAlertOpen = true
        let alert = NSAlert()
        alert.messageText = "Accessibility permission required"
        alert.informativeText = "Grant SpacePeek access under System Settings > Privacy & Security > Accessibility. SpacePeek will start watching automatically once access is granted."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        accessibilityAlertOpen = false
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func openSettings() {
        PreferencesWindowController.shared.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            PreferencesWindowController.shared.show()
        }
        return true
    }

    @objc private func recheckPermissions() {
        evaluateAccessibility(promptIfMissing: false)
    }

    @objc private func forceScan() {
        watcher?.scanOnce()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func handlePreferencesChange() {
        watcher?.scanOnce()
    }
}

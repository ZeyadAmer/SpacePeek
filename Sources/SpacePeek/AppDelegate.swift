import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var watcher: MissionControlWatcher?
    private var overlayController: LabelOverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = FontImporter.shared
        installStatusItem()
        ensureAccessibility { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.presentAccessibilityAlert()
                return
            }
            self.startWatching()
        }

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

    private func presentAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility permission required"
        alert.informativeText = "Grant SpacePeek access under System Settings > Privacy & Security > Accessibility, then choose Recheck Permissions from the menu bar item."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
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
        ensureAccessibility { [weak self] granted in
            guard let self else { return }
            if granted {
                self.startWatching()
            } else {
                self.presentAccessibilityAlert()
            }
        }
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

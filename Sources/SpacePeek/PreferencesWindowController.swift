import AppKit
import SwiftUI

final class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "SpacePeek Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("SpacePeekSettings")
        window.tabbingMode = .disallowed
        window.delegate = WindowRetainer.shared

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }
}

private final class WindowRetainer: NSObject, NSWindowDelegate {
    static let shared = WindowRetainer()

    func windowWillClose(_ notification: Notification) {
        PreferencesWindowController.shared.close()
    }
}

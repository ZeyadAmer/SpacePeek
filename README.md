# SpacePeek

Tiny macOS menu bar app that labels every space in Mission Control's top strip so you can identify each desktop and full-screen app at a glance — no hover required.

## Why

Mission Control's Spaces strip only shows a space's name when you hover it. With 10+ full-screen apps, that turns into a guessing game. SpacePeek paints the name under every tile, always.

## Features

- Always-visible names under every space tile in Mission Control's top strip
- **Settings window** with three tabs: General, Per-Space, App Rules
- **Per-space renames** that survive tab switches and file changes (override key = post-strategy base name, so the VSCode folder or Chrome window name stays stable)
- **App Rules** — apply a title-extraction strategy per app (Raw, Folder name, File name, App profile)
- **Custom fonts** — import any `.ttf` / `.otf` / `.ttc` file and use it for labels
- Adjustable label size and bold toggle
- 18-character cap with `…` ellipsis on every label (raw, processed, or user-renamed)
- Smart hover handling — labels hide while you interact with a tile, then return at corrected positions after Apple's collapse animation finishes
- Zero background AX activity until Mission Control opens
- Lives in the menu bar — no Dock icon, no window
- Apple Accessibility API only (no private APIs)

## Install

Download → drag → strip quarantine → run.

1. Download the latest `SpacePeek-x.y.z.dmg` from [Releases](../../releases).
2. Open the DMG and drag **SpacePeek** into **Applications**.
3. **Bypass Gatekeeper** — the app is ad-hoc signed, not Developer-ID signed, so macOS Sequoia blocks first launch with *"Apple could not verify SpacePeek is free of malware"*. Choose one:

   **Option A — Terminal one-liner (fastest):**
   ```bash
   xattr -dr com.apple.quarantine /Applications/SpacePeek.app
   ```
   Then double-click SpacePeek to launch normally.

   **Option B — System Settings (no terminal):**
   1. Double-click SpacePeek → hit **Done** on the block dialog.
   2. Open **System Settings → Privacy & Security**.
   3. Scroll down. You will see *"SpacePeek was blocked to protect your Mac."* → click **Open Anyway**.
   4. Confirm the next dialog with **Open**.

4. Grant **Accessibility** access when prompted (System Settings → Privacy & Security → Accessibility → toggle **SpacePeek** on).
5. Done. SpacePeek runs silently in the menu bar — no Dock icon, no window. Trigger Mission Control (three-finger swipe up, F3, or Ctrl + ↑) and labels appear under every tile.

> **Why the Gatekeeper warning?** SpacePeek is currently ad-hoc signed because there is no paid Apple Developer ID behind the project yet. Once that is in place (see Roadmap), releases will be Developer-ID signed and notarized, and recipients will just double-click to launch.

### Run at login (optional)

To have SpacePeek start automatically in the background on every boot:

System Settings → General → Login Items → **Open at Login** → **+** → pick **SpacePeek** from Applications.

That's it. No terminal involvement at any point.

### Updating to a new version

SpacePeek is unsigned, so every new build has a different code hash. macOS treats the new build as a different app for Accessibility purposes, which means the old toggle in *Privacy & Security → Accessibility* no longer authorises anything. Replace the app and reset the permission before launching:

```bash
# 1. Quit the running app
pkill -f SpacePeek

# 2. Remove the old install
rm -rf /Applications/SpacePeek.app

# 3. Drag the new SpacePeek.app from the freshly downloaded DMG into /Applications
#    (Finder), then strip quarantine on the new copy:
xattr -dr com.apple.quarantine /Applications/SpacePeek.app

# 4. Wipe the stale Accessibility entry so the new code hash gets a clean prompt
tccutil reset Accessibility com.zeyadamer.spacepeek

# 5. Launch
open /Applications/SpacePeek.app
```

After launch:

1. Settings → Privacy & Security → Accessibility.
2. Click **+** → ⌘⇧G → paste `/Applications/SpacePeek.app` → Open.
3. Toggle the new **SpacePeek** row on.

If the row is already there but does nothing, click **−** to remove it first, then re-add. The `tccutil reset` step above usually clears it for you.

## Settings

Click the **captions.bubble** icon in the menu bar → **Settings…** (`⌘,`).

### General tab

| Control | What it does |
|---------|--------------|
| **Default strategy** | How a title like `Project — file.tsx` is reduced. `Raw` keeps the full string. `Folder name` keeps the left side of the first separator. `File name` keeps the right side. `App profile` is for browser titles — see below. |
| **Font** | Pick from built-in system fonts or any font you've imported. |
| **Import…** | Pick a `.ttf`, `.otf`, or `.ttc` from disk. SpacePeek copies it into `~/Library/Application Support/SpacePeek/Fonts/`, registers it for the running process, and selects it for you. Re-registered automatically on every launch. |
| **Custom fonts** | Disclosure with a trash button per imported family. Removing also unregisters and deletes the file. |
| **Size** | 9–18 pt slider. |
| **Bold** | Toggle. |
| **Preview** | Three sample labels rendered with the current style. |

### Per-Space tab

Lists every space SpacePeek currently sees in Mission Control, identified by its **base key** (the result of running the title through the current strategy and app rules). For example:

- VSCode space `full screen mac windows naming — LabelOverlayController.swift` with the `Folder name` strategy → base key `full screen mac windows naming`.
- Chrome window named `Work` (via Chrome's *Name window…* feature) → base key `Work`.

Type a rename next to any row. The rename is keyed by the base, so switching files in VSCode or tabs in Chrome does not break the rename.

#### Chrome tip (built-in feature, no extra setup)

Chrome on macOS has a `Name window…` feature. Right-click an empty spot on the tab strip → **Name window…** → enter `Work`, `Personal`, etc. The macOS window title becomes the name you chose and stays put when you switch tabs. SpacePeek picks it up automatically; rename it in the Per-Space tab if you want a different label.

### App Rules tab

Apply a title strategy when a space title contains a given app name (case-insensitive, first match wins). Typical entries:

| App name | Strategy | Why |
|----------|----------|-----|
| `Cursor` | Folder name | Strip the file portion of `folder — file.tsx`. |
| `Code` | Folder name | Same for VSCode. |
| `Xcode` | File name | Show the file you are looking at. |
| `Google Chrome` | App profile | When Chrome shows `Page - Profile` or `Page - Profile - Google Chrome` in the title, extract the profile name. (Only needed if you do not use the *Name window…* trick.) |

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon (Intel build pending)

## Build from source (contributors only)

End users do not need this section — grab the DMG from Releases instead.

```bash
git clone git@github.com:ZeyadAmer/SpacePeek.git
cd SpacePeek
bash scripts/build-app.sh
# → dist/SpacePeek.app + dist/SpacePeek-x.y.z.dmg
```

Run directly without packaging:

```bash
swift run SpacePeek
```

### Cut a release

```bash
# 1. build the DMG
bash scripts/build-app.sh

# 2. tag the commit
git tag v0.2.0
git push origin v0.2.0

# 3. publish on GitHub Releases with the DMG attached
gh release create v0.2.0 dist/SpacePeek-0.2.0.dmg \
  --title "SpacePeek 0.2.0" \
  --notes $'Settings window, per-space renames, App Rules, custom font import. Drag the DMG to Applications, then strip quarantine to bypass Gatekeeper:\n\n    xattr -dr com.apple.quarantine /Applications/SpacePeek.app\n\nOr System Settings → Privacy & Security → Open Anyway. Then grant Accessibility access.'
```

Bump version in `scripts/build-app.sh` and the DMG filename for subsequent releases.

## How it works

SpacePeek reads the Dock process's Accessibility tree to find the `Spaces Bar` element Apple exposes when Mission Control is open. For each tile it reads the raw title and the tile's screen frame, runs the title through the configured strategy and app rules, applies any user rename, truncates to 18 characters, and renders a borderless overlay window above the shielding window level positioned directly under the tile.

Hover detection compares the cursor position to a cached union of tile bounds. When the cursor enters the strip band, all labels `orderOut` in a single batched transition so Apple's tile-expand animation runs uninterrupted. When the cursor leaves, a 300 ms delay lets Apple's strip-collapse animation finish, then SpacePeek re-scans the AX tree to capture the rested tile positions before showing the labels at the correct coordinates.

Preferences are encoded as JSON and persisted under `SpacePeek.Preferences.v1` in `UserDefaults`. Imported fonts live under `~/Library/Application Support/SpacePeek/Fonts/` and are re-registered via `CTFontManagerRegisterFontsForURL` on every launch.

## Project layout

```
Sources/SpacePeek/
  main.swift                     NSApplication entry
  AppDelegate.swift              Status bar + perm gate + wiring
  AccessibilityGate.swift        AXIsProcessTrustedWithOptions prompt
  MissionControlWatcher.swift    Detection + refresh polling
  ThumbnailScanner.swift         Walks Dock AX tree, extracts Spaces Bar tiles
  LabelOverlayController.swift   One borderless NSWindow per tile, hover gating
  LabelView.swift                White text + shadow, single-line ellipsis
  Thumbnail.swift                Frame + raw title + display title
  TitleProcessor.swift           Strategy + rename + truncation pipeline
  Preferences.swift              Codable model + UserDefaults store
  SpacesSnapshotStore.swift      Feeds detected base keys into the Settings UI
  FontImporter.swift             Custom font copy + register + list
  PreferencesWindowController.swift  NSHostingController wrapper
  SettingsView.swift             SwiftUI tabbed settings
Resources/
  Info.plist                     Bundle metadata, LSUIElement true
  AppIcon.icns                   Generated by scripts/make-icon.swift
scripts/
  build-app.sh                   Release build → .app → ad-hoc sign → .dmg
  make-icon.swift                Renders icon set + runs iconutil
```

## Roadmap

- [ ] Universal binary (arm64 + x86_64)
- [ ] Developer-ID signed + notarized release
- [ ] Launch at login (`SMAppService`)
- [ ] Optional dark / light label themes
- [ ] Per-app font overrides
- [ ] Export / import preferences

## License

MIT — see [LICENSE](LICENSE).

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

Signed with Apple Developer ID and notarized by Apple — Gatekeeper accepts it on first launch.

1. Download the latest `SpacePeek-x.y.z.dmg` from [Releases](../../releases).
2. Open the DMG and drag **SpacePeek** into **Applications**.
3. Double-click **SpacePeek** in `/Applications` to launch.
4. Grant **Accessibility** access when prompted (System Settings → Privacy & Security → Accessibility → toggle **SpacePeek** on). SpacePeek auto-starts watching the moment the toggle flips.
5. Done. SpacePeek runs silently in the menu bar — no Dock icon, no window. Trigger Mission Control (three-finger swipe up, F3, or Ctrl + ↑) and labels appear under every tile.

### Run at login (optional)

System Settings → General → Login Items → **Open at Login** → **+** → pick **SpacePeek** from Applications.

### Updating to a new version

Drag the new `SpacePeek.app` from the latest DMG into `/Applications`, overwriting the old one. Because the Developer ID identity is stable across releases, your existing Accessibility grant carries over — no re-prompting, no `tccutil reset` required.

## Uninstall

Remove SpacePeek and every trace it leaves behind — permissions, preferences, custom fonts, caches:

```bash
# Quit the app
osascript -e 'tell application "SpacePeek" to quit' 2>/dev/null
pkill -f SpacePeek 2>/dev/null

# Remove the app
rm -rf /Applications/SpacePeek.app
rm -rf ~/Applications/SpacePeek.app

# Remove preferences, saved state, caches
defaults delete com.zeyadamer.spacepeek 2>/dev/null
rm -f  ~/Library/Preferences/com.zeyadamer.spacepeek.plist
rm -rf ~/Library/Saved\ Application\ State/com.zeyadamer.spacepeek.savedState
rm -rf ~/Library/Caches/com.zeyadamer.spacepeek
rm -rf ~/Library/HTTPStorages/com.zeyadamer.spacepeek
rm -rf ~/Library/WebKit/com.zeyadamer.spacepeek
rm -rf ~/Library/Containers/com.zeyadamer.spacepeek

# Remove custom fonts and Application Support data
rm -rf ~/Library/Application\ Support/SpacePeek

# Reset Accessibility (and any other) TCC permissions
tccutil reset All com.zeyadamer.spacepeek

# Force preferences daemon to reload
killall cfprefsd 2>/dev/null

echo "SpacePeek fully wiped."
```

After running, **System Settings → Privacy & Security → Accessibility** no longer lists SpacePeek. A fresh install behaves like first-ever launch.

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

Signed + notarized release requires a paid Apple Developer Program account, a `Developer ID Application` certificate, and a stored notary credential profile.

```bash
# One-time setup (per machine)
xcrun notarytool store-credentials notary-spacepeek \
  --apple-id you@example.com \
  --team-id YOURTEAMID \
  --password xxxx-xxxx-xxxx-xxxx       # app-specific password from appleid.apple.com

# Per release
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (YOURTEAMID)"
export NOTARY_PROFILE="notary-spacepeek"

bash scripts/build-app.sh
# → dist/SpacePeek.app + dist/SpacePeek-x.y.z.dmg + .zip, all signed, notarized, stapled

git tag v1.0.0
git push origin v1.0.0

gh release create v1.0.0 \
  dist/SpacePeek-1.0.0.dmg \
  dist/SpacePeek-1.0.0.zip \
  --title "SpacePeek 1.0.0" \
  --notes-file RELEASE_NOTES.md
```

If `DEVELOPER_ID_APPLICATION` is unset, the script falls back to ad-hoc signing (local dev only — Gatekeeper will reject those builds on other machines).

Bump version in both `scripts/build-app.sh` and `Resources/Info.plist` (`CFBundleShortVersionString` + `CFBundleVersion`) for subsequent releases.

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
  build-app.sh                   Release build → .app → Developer ID sign → notarize → staple → .dmg + .zip
  make-icon.swift                Renders icon set + runs iconutil
```

## Roadmap

- [x] Developer-ID signed + notarized release
- [ ] Universal binary (arm64 + x86_64)
- [ ] Launch at login (`SMAppService`)
- [ ] Optional dark / light label themes
- [ ] Per-app font overrides
- [ ] Export / import preferences

## License

MIT — see [LICENSE](LICENSE).

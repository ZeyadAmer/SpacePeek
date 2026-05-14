# SpacePeek

Tiny macOS menu bar app that labels every space in Mission Control's top strip so you can identify each desktop and full-screen app at a glance — no hover required.

## Why

Mission Control's Spaces strip only shows a space's name when you hover it. With 10+ full-screen apps, that turns into a guessing game. SpacePeek paints the name under every tile, always.

## Features

- Always-visible names under every space tile in Mission Control's top strip
- Smart hover handling — labels hide while you interact with a tile, then return at corrected positions
- Zero background AX activity until Mission Control opens
- Single-line ellipsis truncation for long names
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

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon (Intel build pending)

## Build from source (contributors only)

End users do not need this section — grab the DMG from Releases instead.

```bash
git clone git@github.com:ZeyadAmer/SpacePeek.git
cd SpacePeek
bash scripts/build-app.sh
# → dist/SpacePeek.app + dist/SpacePeek-0.1.0.dmg
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
git tag v0.1.0
git push origin v0.1.0

# 3. publish on GitHub Releases with the DMG attached
gh release create v0.1.0 dist/SpacePeek-0.1.0.dmg \
  --title "SpacePeek 0.1.0" \
  --notes $'Initial release. Drag the DMG to Applications, then strip quarantine to bypass Gatekeeper:\n\n    xattr -dr com.apple.quarantine /Applications/SpacePeek.app\n\nOr System Settings → Privacy & Security → Open Anyway. Then grant Accessibility access.'
```

Bump version in `scripts/build-app.sh` and the DMG filename for subsequent releases.

## How it works

SpacePeek reads the Dock process's Accessibility tree to find the `Spaces Bar` element Apple exposes when Mission Control is open. For each tile it reads the title (e.g. `Claude`, `Desktop 1`) and the tile's screen frame, then renders a borderless overlay window above the shielding window level with a single-line label positioned directly under the tile.

Hover detection compares the cursor position to a cached union of tile bounds. When the cursor enters the strip band, all labels `orderOut` in a single batched transition so Apple's tile-expand animation runs uninterrupted. When the cursor leaves, a 300 ms delay lets Apple's strip-collapse animation finish, then SpacePeek re-scans the AX tree to capture the rested tile positions before showing the labels at the correct coordinates.

## Project layout

```
Sources/SpacePeek/
  main.swift                   NSApplication entry
  AppDelegate.swift            Status bar + perm gate + wiring
  AccessibilityGate.swift      AXIsProcessTrustedWithOptions prompt
  MissionControlWatcher.swift  Detection + refresh polling
  ThumbnailScanner.swift       Walks Dock AX tree, extracts Spaces Bar tiles
  LabelOverlayController.swift One borderless NSWindow per tile, hover gating
  LabelView.swift              White text + shadow, single-line ellipsis
  Thumbnail.swift              Frame + title struct
Resources/
  Info.plist                   Bundle metadata, LSUIElement true
  AppIcon.icns                 Generated by scripts/make-icon.swift
scripts/
  build-app.sh                 Release build → .app → ad-hoc sign → .dmg
  make-icon.swift              Renders icon set + runs iconutil
```

## Roadmap

- [ ] Universal binary (arm64 + x86_64)
- [ ] Developer-ID signed + notarized release
- [ ] Launch at login (`SMAppService`)
- [ ] Optional dark / light label themes
- [ ] Configurable max characters and font size

## License

MIT — see [LICENSE](LICENSE).

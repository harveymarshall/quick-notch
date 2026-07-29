# Quick Notch

Mac menu-bar / notch capture app: type a quick note in the notch UI, and it saves a Markdown file into a local folder you choose (perfect for an Obsidian vault).

## Download (DMG)

Users download the app from **GitHub Releases** (not from git history — `.dmg` files stay out of the repo).

1. Open the repo **Releases** page
2. Download `QuickNotch-x.y.z.dmg`
3. Open the DMG and drag **QuickNotch** into **Applications**
4. First launch: right-click the app → **Open** (ad-hoc signed builds are blocked by Gatekeeper until you approve once)

### Automatic releases

Every merge to `main` runs [Build DMG](.github/workflows/build-dmg.yml), which:

1. Auto-bumps the patch version from the latest `v*` tag (or starts at `1.0.0`)
2. Builds a universal DMG
3. Creates a GitHub Release for that version and attaches the DMG

You can also run the workflow manually from the Actions tab and optionally pass a version override.

### Build a DMG locally

```bash
./scripts/package-dmg.sh
# → dist/QuickNotch-1.0.0.dmg

VERSION=1.2.3 ./scripts/package-dmg.sh
# → dist/QuickNotch-1.2.3.dmg
```

Uses full Xcode when available; otherwise Command Line Tools + `swiftc` (universal `arm64` + `x86_64` by default).
## Use

1. Launch **Quick Notch** (menu bar icon appears; no Dock icon)
2. Open **Settings…** from the menu bar icon and choose your notes folder (e.g. an Obsidian vault path)
3. Capture by moving the cursor up into the **camera notch**, or with:
   - Menu bar → **Capture Note**
   - Hotkey **⌘⇧N**
4. Type your note → **Save** (**⌘S**) writes a `.md` file into that folder
5. **Esc** cancels (or move away if the note is still empty)

### File format

Notes look like:

```markdown
---
created: 2026-07-26T14:30:00Z
source: Quick Notch
---

# First line becomes the title

Remaining lines are the body.
```

Filename pattern: `yyyy-MM-dd-HHmmss-slug.md`

## Develop

Requires macOS 14+ and Xcode.

```bash
open QuickNotch.xcodeproj
```

Or build from the CLI:

```bash
xcodebuild -project QuickNotch.xcodeproj -scheme QuickNotch -configuration Debug -destination 'platform=macOS' build
```

## Notes

- Sandbox is off so the app can write to any folder you select (Obsidian vaults, iCloud paths, etc.).
- DMGs from CI are **ad-hoc signed**. For Gatekeeper-clean installs later, add Apple Developer ID signing + notarization to `scripts/package-dmg.sh` and the workflow.

# Building the client with Skywave

This guide is for building the upstream Apple client with Skywave inside it. It assumes:

- `$UPSTREAM` is a checkout of <https://github.com/SagerNet/sing-box> with submodules.
- `$SKIN` is a checkout of this repository.

## 1. Prepare upstream

```bash
git -C "$UPSTREAM" submodule update --init --recursive
```

This brings in `clients/apple` and its `Frameworks/Runestone`.

Then build Libbox with upstream's own tooling. This needs Go, plus gomobile, which
`make lib_install` installs:

```bash
make -C "$UPSTREAM" lib_install lib_apple
```

The result is `Libbox.xcframework`, which the Xcode project references.

## 2. Apply Skywave

```bash
python3 "$SKIN/Integration/apply_to_upstream.py" "$UPSTREAM/clients/apple"
```

The script uses the GitHub package `https://github.com/SadNoo/SB-Skin` on branch `main`. It
accepts these options:

- `--local "$SKIN"` uses your checkout instead of GitHub.
- `--branch` / `--url` pin a different branch or fork.
- `--app-name` sets the product name that replaces the upstream name in visible places
  (default `Skywave`). This always runs: the upstream license forbids using the upstream name
  or implying association. It changes:
  - `CFBundleDisplayName` of every app target
  - the Mac window title, Quit menu item and menu-bar label
  - the VPN server label
  - the Files app domain name
  - the Control Center toggle

The script is idempotent: running it again changes nothing. It makes these changes:

| Where | Change |
|---|---|
| `SFI/SkywaveIntegration/`, `MacLibrary/SkywaveIntegration/` | Adds `UpstreamSkinBackend.swift` and `SkinIntegration.swift`. Both folders are synchronized groups, so no project edit is needed for them. |
| `SFI/MainView.swift` | `tabViewContent` returns `SkinIntegrationRoot()`. The original stays as `upstreamTabViewContent`. `openURL` offers skin deep links first. |
| `MacLibrary/MainView.swift` | The `NavigationSplitView` and its toolbar are replaced by `SkinIntegrationRoot()`. Window setup, alerts, global checks and URL handling stay. |
| `WidgetExtension/ExtensionBundle.swift` | Adds `SkinStatusWidget()` and `SkinLiveActivityWidget()` next to the upstream control. |
| `SFI/Info.plist` | `NSSupportsLiveActivities = YES` |
| Icons (SFI, WidgetExtension, ActionExtension, MacLibrary) | Every upstream icon is replaced with Skywave's; the Mac menu bar glyph too. See "Branding rules" below. |
| Visible names | The upstream name becomes `--app-name` (default Skywave) in display names and labels. |
| `project.pbxproj` | Adds the Skywave package and links `Skywave` → SFI and MacLibrary, and `SkywaveWidgets` → WidgetExtension. Deployment targets go to iOS 26.0 (SFI, WidgetExtension) and macOS 26.0 (SFM, SFM.System, MacLibrary). |

Nothing in the core changes: Go, Libbox, the network and system extensions, profiles and
settings. Skywave talks to the core only through the APIs the upstream UI already uses:

- `ExtensionEnvironments` and `CommandClient`
- `ExtensionProfile`
- `CommandTarget.standaloneClient()`
- `ProfileManager` and `SharedPreferences`
- `SystemExtension`

## 3. Build

Open `$UPSTREAM/clients/apple/sing-box.xcodeproj`, or use `xcodebuild` with the upstream
schemes: `SFI` for iOS/iPadOS, `SFM` for macOS App Store, and `SFM.System` for the standalone
macOS build. Signing, bundle IDs and App Groups are configured the same way as upstream.

- **Widgets.** The app writes a small JSON snapshot to the App Group that the Info.plist key
  `AppGroupIdentifier` names, and the widgets read it. Upstream already defines that key and
  the App Group entitlement for both SFI and WidgetExtension.
- **Deep links.** Widgets and the Live Activity open
  `<first CFBundleURLSchemes entry>://skywave/<home|nodes|activity|start|stop|toggle>`.
  `SkinIntegration.handle` consumes these links. Every other URL still reaches the upstream
  handler.
- **Icon follows skin (iOS).** The script copies one alternate icon per skin into
  `SFI/Assets.xcassets` (`AppIcon-Native`, `AppIcon-Instrument`, …; Radio uses the primary
  icon). The SFI target already compiles all app icon sets, and `SkinIntegration` passes
  `SkinConfiguration.skywaveAlternateIcons`, so "App Icon Follows Skin" in Settings ›
  Appearance works out of the box.

## 4. Things to check after building

1. First launch shows the skin picker and the "unofficial third-party app" line. Pick a skin,
   and later change it in Settings › Appearance; with "App Icon Follows Skin" on, the home
   screen icon changes color.
2. The home screen, Settings, widgets, Mac Dock and Mac menu bar all show the Skywave name
   and icon, never the upstream ones.
3. On iOS, when no VPN configuration is installed yet, the skin shows
   "Install Network Extension". On macOS with the system extension, it shows
   "Install System Extension".
4. Start and stop the service, switch profile, select a node, run a URL test and change the
   mode. On macOS, toggle the system proxy.
5. The Connections list opens a connection detail, can close one connection or all of them,
   and filters. Logs stream, filter by level, and clear.
6. Remote control (macOS / iOS): a banner shows the remote device, with a Disconnect button.
7. Importing a remote profile link still shows the upstream import sheet.
8. The Home Screen widget, Lock Screen widgets and Live Activity / Dynamic Island update while
   connected.

## Updating

When upstream changes, re-run the script on a fresh checkout. If a patch point moved, the
script stops with a message that names the file. Earlier steps may already have been
applied, so reset the checkout (`git -C "$UPSTREAM/clients/apple" checkout . && git clean -fd`).
Then adjust the matching function in `apply_to_upstream.py`, or patch that file by hand as
the table above describes.

If upstream renames an API that the glue uses, update:

- `Integration/Apple/*.swift`
- the stubs in `Integration/TypeCheck/Sources/*`, so `swift build --package-path Integration/TypeCheck`
  keeps guarding the glue.

## Branding rules

Skywave must never look like the official client:

- **Icons.** The script replaces every upstream icon with the ones in `Branding/`: the iOS app
  icon and per-skin alternates, the widget, the share extension, the Mac app (`AppIcon.icon`,
  the asset catalog icon and `AppIcon.icns`) and the Mac menu bar glyph. Regenerate them with
  `python3 Branding/make_icons.py`.
- **Name.** Keep `--app-name` at Skywave (or your own name). Never ship the upstream name.
- **Statement.** The app states it is unofficial on first launch and in Settings › About. Keep
  that text.
- **Apple TV.** Skywave has no tvOS skins. Do not build or ship the upstream `SFT` target: it
  still carries the upstream look and icons.
- **Store listing.** Describe Skywave as a third-party interface. Mentioning compatibility with
  the core in the description is fine; using its name or logo in the title, icon or
  screenshots is not.

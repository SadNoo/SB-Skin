# Building the client with SB-Skin

This guide is for building the upstream Apple client with SB-Skin inside it. It assumes:

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

## 2. Apply SB-Skin

```bash
python3 "$SKIN/Integration/apply_to_upstream.py" "$UPSTREAM/clients/apple" --app-name "Codename"
```

The script uses the GitHub package `https://github.com/SadNoo/SB-Skin` on branch `main`. It
accepts these options:

- `--local "$SKIN"` uses your checkout instead of GitHub.
- `--branch` / `--url` pin a different branch or fork.
- `--app-name` replaces the upstream product name in visible places. The upstream license
  requires it, and the default placeholder is "Codename". It changes:
  - `CFBundleDisplayName` of every app target
  - the Mac window title, Quit menu item and menu-bar label
  - the VPN server label
  - the Files app domain name
  - the Control Center toggle

The script is idempotent: running it again changes nothing. It makes these changes:

| Where | Change |
|---|---|
| `SFI/SBSkinIntegration/`, `MacLibrary/SBSkinIntegration/` | Adds `UpstreamSkinBackend.swift` and `SkinIntegration.swift`. Both folders are synchronized groups, so no project edit is needed for them. |
| `SFI/MainView.swift` | `tabViewContent` returns `SkinIntegrationRoot()`. The original stays as `upstreamTabViewContent`. `openURL` offers skin deep links first. |
| `MacLibrary/MainView.swift` | The `NavigationSplitView` and its toolbar are replaced by `SkinIntegrationRoot()`. Window setup, alerts, global checks and URL handling stay. |
| `WidgetExtension/ExtensionBundle.swift` | Adds `SkinStatusWidget()` and `SkinLiveActivityWidget()` next to the upstream control. |
| `SFI/Info.plist` | `NSSupportsLiveActivities = YES` |
| `project.pbxproj` | Adds the SB-Skin package and links `SBSkin` → SFI and MacLibrary, and `SBSkinWidgets` → WidgetExtension. Deployment targets go to iOS 26.0 (SFI, WidgetExtension) and macOS 26.0 (SFM, SFM.System, MacLibrary). |

Nothing in the core changes: Go, Libbox, the network and system extensions, profiles and
settings. SB-Skin talks to the core only through the APIs the upstream UI already uses:

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
  `<first CFBundleURLSchemes entry>://sbskin/<home|nodes|activity|start|stop|toggle>`.
  `SkinIntegration.handle` consumes these links. Every other URL still reaches the upstream
  handler.
- **Skin sync across devices (optional).** "Sync Skin Across Devices" uses iCloud key-value
  storage. Upstream does not have that entitlement, so the script leaves signing alone. To
  enable sync, add this to `SFI/SFI.entitlements`, `SFM/SFM.entitlements` and
  `SFM.System/SFM.entitlements`:

  ```xml
  <key>com.apple.developer.ubiquity-kvstore-identifier</key>
  <string>$(TeamIdentifierPrefix)$(BASE_PACKAGE_IDENTIFIER)</string>
  ```

  Use the same identifier on every platform so iPhone, iPad and Mac share the value. Without
  the entitlement, the choice stays per device.
- **Alternate app icons (optional).** Nothing ships yet, because the name and icon are still
  undecided. To add them:
  1. Add alternate icon sets to the app's asset catalog.
  2. List them in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
  3. Pass them to `SkinConfiguration(alternateIcons: [.radio: "AppIcon-Radio", ...])` in
     `SkinIntegration.configuration(for:)`.

  "App Icon Follows Skin" then switches icons with the skin. While the map is empty, the
  toggle stays hidden.

## 4. Things to check after building

1. First launch shows the skin picker. Pick a skin, and later change it in
   Settings › Appearance.
2. On iOS, when no VPN configuration is installed yet, the skin shows
   "Install Network Extension". On macOS with the system extension, it shows
   "Install System Extension".
3. Start and stop the service, switch profile, select a node, run a URL test and change the
   mode. On macOS, toggle the system proxy.
4. The Connections list opens a connection detail, can close one connection or all of them,
   and filters. Logs stream, filter by level, and clear.
5. Remote control (macOS / iOS): a banner shows the remote device, with a Disconnect button.
6. Importing a remote profile link still shows the upstream import sheet.
7. The Home Screen widget, Lock Screen widgets and Live Activity / Dynamic Island update while
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

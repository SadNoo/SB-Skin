# Design notes

## Principle

A skin changes how the app looks and how you move through it. It never changes what the app
can do. Every skin reaches the same features: service, profiles, groups and nodes, URL tests,
mode, system proxy, connections, logs, remote control, tools and settings. Where a skin has no
room for something, it links to a shared page.

## Layers

```
 host app (upstream, or Demo)
   │  SkinSession(backend:configuration:preferences:)
   ▼
 SkinRootView ── onboarding, alerts, remote banner, ⌘K palette, ⌃⌘S, system surfaces
   │
 SkinCanvas ─── theme tokens + the chosen skin's view
   │
 Skins/<Skin>/  compact (iPhone) and regular (iPad / Mac) layouts
   │  read SkinStore, call SkinStore actions
   ▼
 SkinStore (@Observable, @MainActor) ── the only state skins see
   │  actions are optimistic, then forwarded
   ▼
 SkinBackend (protocol)
   ├─ MockSkinBackend            demo, previews, thumbnails, tests
   └─ UpstreamSkinBackend        Integration/Apple, wraps the upstream client APIs
```

- **SkinStore** holds plain value models: `SkinOutboundGroup`, `SkinConnection`,
  `SkinLogEntry`, `RuntimeStatus` and so on. No upstream type leaks into a skin, which is why
  the skins build and run without Libbox.
- **SkinBackend** mirrors what the upstream UI does. It exposes:
  - start / stop and profile selection
  - `selectOutbound`, `urlTest`, `setGroupExpanded`, `setClashMode`, `setSystemProxyEnabled`
  - `closeConnection` / `closeAllConnections` and `clearLogs`
  - `performSetup` (install the network or system extension)
  - `disconnectRemote`

  Connections and logs are subscribed on demand (retain / release), so the core only streams
  them while a page needs them.
- **SkinConfiguration** carries what only the host knows: app name, URL scheme, whether to
  run Live Activities and widget snapshots, alternate icons, and the host pages. The host pages
  are closures that return the upstream Profiles, Tools, Settings and Remote Control views.
- **SkinPreferences** hold the skin, onboarding state, wording, color mode, icon choice, Bento
  layout, log level and Radio band. They live in the app's own defaults, and optionally in
  iCloud key-value storage.

## Themes

`SkinTheme` defines each skin's tokens: colors for light and dark, corner radii, text design,
card style and whether the skin forces a color mode (Instrument is dark only). The shared pages
and the upstream host pages read these tokens, so they look at home in any skin.

## Adaptive layout

Each skin decides between `compact` and `regular` from `horizontalSizeClass`. Regular layouts
use split views, side rails or multi-column dashboards. They adapt further with
`ViewThatFits` and `onGeometryChange`: for example, Instrument's table drops the rule column
below 760 pt. Mac uses the regular layouts inside a window.

## System surfaces

`SystemSurfacesSync` watches the store and does two things:

- writes a `SkinWidgetSnapshot` (JSON) to the App Group, and reloads widget timelines when
  something visible changed;
- starts, updates and ends the Live Activity for the running service (iOS).

Widgets never talk to the core. They render the snapshot, and their buttons deep-link back
into the app (`<scheme>://sbskin/<action>`).

## Localization

Strings are English keys looked up in each module's own `Localizable.xcstrings` through
`SkinL`, `SharedL` and `WidgetL`. `Scripts/l10n/build_catalogs.py` extracts the keys and fills
the catalogs from `Scripts/l10n/<locale>.json`. Radio's silk-screen labels ("ON AIR",
"POWER · ON") stay English on purpose, like the lettering on real hardware.

## Naming

The upstream name never appears in SB-Skin's UI. The app name comes from the host bundle, and
`apply_to_upstream.py --app-name` removes the remaining upstream labels from the host.

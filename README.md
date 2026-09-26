# SB-Skin

**English** · [简体中文](README.zh-Hans.md)

Third-party skins for the Apple client of an open-source universal proxy platform (sing-box,
<https://github.com/SagerNet/sing-box>). SB-Skin replaces the client's navigation with eight
interchangeable interfaces and leaves every feature as it was. You can switch skins at any
time.

> SB-Skin is an independent project. It has no affiliation with the upstream authors. The
> upstream license does not allow derivative works to use the upstream name, so SB-Skin never
> shows it in its interface. The integration script can also remove it from the host app
> (`--app-name`).

![All eight skins on iPhone](docs/images/iphone-skins.jpg)

## Skins

| Skin | For | Idea |
|---|---|---|
| **System Native** | People who want it stable and familiar | Feels like Apple made it: Liquid Glass, tab bar, grouped cards |
| **Instrument** | Power users who like live data | Dark control panel, every number on screen, dense tables |
| **One Tap** | People who just want the network to work | One big power button and one current place |
| **Places** | People who prefer plain words over jargon | A dot-matrix world map; nodes are places, latency is "how the road is" |
| **Transparent** | People who want to understand routing rules | Follow every connection from app → rule → group → exit |
| **One Sentence** | People who like calm, beautiful typography | The whole state in one editorial sentence; tap the underlined words to change them |
| **Radio** | People who love tactile hardware | An LCD, a tuning knob with haptics, piano keys; logs print as a receipt |
| **Bento** | Tinkerers who want to customize | Rearrange modules; dot-matrix numerals |

Every skin has an iPhone layout and a regular-width layout for iPad and Mac:

![Four skins on iPad](docs/images/ipad-skins.jpg)

All skins share these:

- **First-launch picker.** It shows live miniatures of every skin, and the same picker lives
  in Settings › Appearance.
- **Command palette (⌘K).** Switch skins with ⌃⌘S.
- **Wording.** Choose everyday words ("Smart routing", "Very fast") or technical terms
  ("Rule", "186 ms").
- **Per device.** Each device remembers its own skin; nothing is synced, so devices on
  different SB-Skin versions never conflict.
- **App icon.** An optional alternate app icon can follow the skin.
- **Widgets and Live Activity.** Home Screen and Lock Screen widgets, a Live Activity and
  the Dynamic Island.
- **Languages.** English, Simplified Chinese and Traditional Chinese.

The upstream Profiles, Tools and Settings screens stay upstream code. The skins host them and
tint them to match.

## Requirements

- iOS / iPadOS 26 or macOS 26
- Xcode 26 or later (Swift 6.2 tools)

## Repository layout

```
Sources/SBSkinShared   Formatting, vocabulary, widget snapshot, deep links (app + widgets)
Sources/SBSkin         The skins, shared pages, store, theme and system-surface sync
Sources/SBSkinWidgets  Status widget and Live Activity
Integration/Apple      Glue between SBSkin and the upstream Apple client
Integration/TypeCheck  Signature stubs for type-checking the glue without building Libbox
Integration/apply_to_upstream.py   Wires SB-Skin into an upstream checkout
Demo/                  Stand-alone demo app with mock data (xcodegen)
Scripts/l10n           Translation tables and the catalog generator
```

## Try the demo

```bash
brew install xcodegen
```

```bash
cd Demo && xcodegen && open SBSkinDemo.xcodeproj
```

The demo accepts these launch arguments:

- `-sbskin-skin <native|instrument|focus|places|lens|sentence|radio|bento>` picks a skin.
- `-sbskin-scenario <live|frozen|stopped|empty>` picks the mock data.
- `-sbskin-onboarding` shows the first-launch picker.

## Build the real client

See [INTEGRATION.md](INTEGRATION.md). In short, you run one script against an upstream
`clients/apple` checkout, then build as usual.

## Development

```bash
swift test
```

```bash
swift build --package-path Integration/TypeCheck
```

```bash
python3 Scripts/l10n/build_catalogs.py
```

`swift test` runs the unit tests. Set `SBSKIN_SNAPSHOTS=<dir>` to also render Mac snapshots of
every skin. The `Integration/TypeCheck` build type-checks the upstream glue against the stubs.
`build_catalogs.py` regenerates the string catalogs after you change strings.

Architecture notes are in [DESIGN.md](DESIGN.md).

## License

SB-Skin is free software under the GNU General Public License v3.0 or later. See
[LICENSE](LICENSE) and [COPYING](COPYING).

The bundled dot-matrix font is derived from Doto (SIL Open Font License 1.1). See
`Sources/SBSkin/Resources/Fonts/OFL.txt`. The world map is derived from Natural Earth (public
domain).

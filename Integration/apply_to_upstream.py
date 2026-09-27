#!/usr/bin/env python3
"""
Wire Skywave into a checkout of the sing-box Apple client.

    python3 Integration/apply_to_upstream.py /path/to/sing-box/clients/apple
    python3 Integration/apply_to_upstream.py /path/to/sing-box/clients/apple --local /path/to/SB-Skin

What it does (idempotent; running it twice changes nothing the second time):

1. Copies Integration/Apple/*.swift into <apple>/SFI/SkywaveIntegration/ and
   <apple>/MacLibrary/SkywaveIntegration/ (both are file-system synchronized groups, so the
   files join the SFI and MacLibrary targets without project edits).
2. Patches three upstream Swift files so the skins replace the root navigation:
   - SFI/MainView.swift            (iOS / iPadOS)
   - MacLibrary/MainView.swift     (macOS)
   - WidgetExtension/ExtensionBundle.swift (adds the Skywave widgets and Live Activity)
3. Edits sing-box.xcodeproj/project.pbxproj:
   - adds the Skywave Swift package (GitHub by default, or --local path),
   - links Skywave to SFI and MacLibrary, SkywaveWidgets to WidgetExtension,
   - raises the deployment target of those targets (and the macOS apps) to 26.0.
4. Enables Live Activities in SFI/Info.plist.
5. Replaces the upstream product name with --app-name (default "Skywave") in the app display
   names and the few visible literals (Mac window title, Quit menu, menu bar label, VPN
   server label, Files app domain, Control Center toggle).
6. Replaces every upstream icon (app, alternates, widget, share extension, Mac app, Mac
   menu bar) with the Skywave icons from Branding/.
7. With --team and --bundle-id, signs with your Apple team and moves every bundle ID, App
   Group and iCloud container to your prefix (upstream ships the author's own).

Nothing in the upstream core (Go, Libbox, the network extension) is touched.

SPDX-License-Identifier: GPL-3.0-or-later
"""

import argparse
import os
import plistlib
import random
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MARK = "Skywave"
DEFAULT_URL = "https://github.com/SadNoo/SB-Skin"

INTEGRATION_FILES = ["UpstreamSkinBackend.swift", "SkinIntegration.swift"]
IOS_TARGETS = ["SFI", "WidgetExtension"]
MAC_TARGETS = ["SFM", "SFM.System", "MacLibrary"]


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def matching_brace(text, open_index):
    """Index of the brace that closes the one at open_index (ignores braces in strings)."""
    depth = 0
    in_string = False
    index = open_index
    while index < len(text):
        char = text[index]
        if char == '"' and text[index - 1] != "\\":
            in_string = not in_string
        elif not in_string:
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return index
        index += 1
    fail("unbalanced braces while patching")


# ---------------------------------------------------------------------------
# Swift sources

def patch_import_request(apple):
    """The skin is compiled outside ApplicationLibrary and needs its public API."""
    path = os.path.join(apple, "ApplicationLibrary", "Views", "Profile", "NewProfileView.swift")
    text = read(path)
    anchor = "    public struct ImportRequest: Codable, Hashable, Identifiable {"
    if anchor not in text:
        fail("NewProfileView.swift: ImportRequest not found")
    opening = text.index("{", text.index(anchor))
    closing = matching_brace(text, opening)
    if "public init(name: String, url: String)" in text[opening:closing]:
        return "NewProfileView.ImportRequest initializer already public"
    insertion = text.rfind("\n", opening, closing)
    text = text[:insertion] + (
        "\n\n        // Skywave: allow the app modules to present remote profile imports.\n"
        "        public init(name: String, url: String) {\n"
        "            self.name = name\n"
        "            self.url = url\n"
        "        }"
    ) + text[insertion:]
    write(path, text)
    return "exposed NewProfileView.ImportRequest initializer to app modules"


def patch_ios_main_view(apple):
    path = os.path.join(apple, "SFI", "MainView.swift")
    text = read(path)
    # Newer upstream layouts choose an iPad sidebar before tabViewContent. Patch
    # that common entry point, including checkouts patched by an older script.
    root_anchor = "    private var rootContent: some View {"
    if root_anchor in text:
        root_start = text.index(root_anchor)
        root_open = text.index("{", root_start)
        root_close = matching_brace(text, root_open)
        text = text[:root_open + 1] + "\n        SkinIntegrationRoot()\n    " + text[root_close:]
        url_anchor = "    private func openURL(url: URL) {\n"
        if "SkinIntegration.handle(url, environments: environments)" not in text:
            if url_anchor not in text:
                fail("SFI/MainView.swift: openURL not found")
            text = text.replace(url_anchor, url_anchor +
                                "        if SkinIntegration.handle(url, environments: environments) {\n"
                                "            return\n        }\n", 1)
        write(path, text)
        return "patched SFI/MainView.swift root for iPhone and iPad"
    if "SkinIntegrationRoot()" in text:
        return "SFI/MainView.swift already patched"
    anchor = "    private var tabViewContent: some View {\n"
    if anchor not in text:
        fail("SFI/MainView.swift: tabViewContent not found; upstream changed, patch by hand (see INTEGRATION.md)")
    text = text.replace(
        anchor,
        "    // Skywave: the skins replace the upstream tab view.\n"
        "    private var tabViewContent: some View {\n"
        "        SkinIntegrationRoot()\n"
        "    }\n\n"
        "    private var upstreamTabViewContent: some View {\n",
        1,
    )
    anchor = "    private func openURL(url: URL) {\n"
    if anchor not in text:
        fail("SFI/MainView.swift: openURL not found")
    text = text.replace(
        anchor,
        anchor + "        // Skywave: widget and Live Activity links.\n"
        "        if SkinIntegration.handle(url, environments: environments) {\n"
        "            return\n"
        "        }\n",
        1,
    )
    write(path, text)
    return "patched SFI/MainView.swift"


def patch_mac_main_view(apple):
    path = os.path.join(apple, "MacLibrary", "MainView.swift")
    text = read(path)
    if "SkinIntegrationRoot()" in text:
        return "MacLibrary/MainView.swift already patched"
    body = text.find("public var body: some View {")
    split = text.find("NavigationSplitView {", body)
    if body < 0 or split < 0:
        fail("MacLibrary/MainView.swift: NavigationSplitView not found; patch by hand (see INTEGRATION.md)")
    # NavigationSplitView { sidebar } detail: { detail }
    first_close = matching_brace(text, text.index("{", split))
    detail_open = text.index("{", first_close + 1)
    detail_close = matching_brace(text, detail_open)
    text = text[:split] + "SkinIntegrationRoot() // Skywave: the skins replace the sidebar layout." + text[detail_close + 1:]
    # The upstream window toolbar (start/stop, card management) duplicates skin controls.
    toolbar = text.find(".toolbar {", text.find("SkinIntegrationRoot()"))
    if toolbar >= 0:
        toolbar_close = matching_brace(text, text.index("{", toolbar))
        line_start = text.rfind("\n", 0, toolbar) + 1
        text = text[:line_start] + text[toolbar_close + 1:].lstrip("\n")
    write(path, text)
    return "patched MacLibrary/MainView.swift"


def patch_widget_bundle(apple):
    path = os.path.join(apple, "WidgetExtension", "ExtensionBundle.swift")
    text = read(path)
    if "SkinStatusWidget()" in text:
        return "WidgetExtension/ExtensionBundle.swift already patched"
    if "ServiceToggleControl()" not in text:
        fail("WidgetExtension/ExtensionBundle.swift: ServiceToggleControl() not found")
    text = text.replace("import SwiftUI\n", "import SkywaveWidgets\nimport SwiftUI\n", 1)
    text = text.replace(
        "ServiceToggleControl()\n",
        "ServiceToggleControl()\n"
        "        SkinStatusWidget()\n"
        "        SkinLiveActivityWidget()\n",
        1,
    )
    write(path, text)
    return "patched WidgetExtension/ExtensionBundle.swift"


def patch_info_plist(apple):
    path = os.path.join(apple, "SFI", "Info.plist")
    with open(path, "rb") as handle:
        info = plistlib.load(handle)
    if info.get("NSSupportsLiveActivities") is True:
        return "SFI/Info.plist already has NSSupportsLiveActivities"
    info["NSSupportsLiveActivities"] = True
    with open(path, "wb") as handle:
        plistlib.dump(info, handle)
    return "enabled Live Activities in SFI/Info.plist"


# User-visible literals that carry the upstream name. The upstream license does not let
# derivative works use it, so --app-name swaps them for the new product name.
UPSTREAM_NAME = "sing-box"
NAME_SITES = [
    ("SFI/ApplicationDelegate.swift", 'displayName: "{}"'),
    ("Library/Network/ExtensionProfile.swift", 'tunnelProtocol.serverAddress = "{}"'),
    ("MacLibrary/StatusBarController.swift", 'NSTextField(labelWithString: "{}")'),
    ("MacLibrary/MacApplication.swift", 'Window("{}", id: "main"'),
    ("MacLibrary/MacApplication.swift", 'Button("Quit {}")'),
    ("WidgetExtension/ServiceToggleControl.swift", 'ControlWidgetToggle(\n                "{}",'),
    ("FileProviderExtension/FileProviderItem.swift", 'return "{}"'),
]


def rename_app(apple, name):
    notes = []
    for relative, template in NAME_SITES:
        path = os.path.join(apple, relative)
        if not os.path.exists(path):
            notes.append(f"{relative} not found, skipped")
            continue
        text = read(path)
        old, new = template.format(UPSTREAM_NAME), template.format(name)
        if old in text:
            write(path, text.replace(old, new))
            notes.append(f"renamed app in {relative}")
    project = os.path.join(apple, "sing-box.xcodeproj", "project.pbxproj")
    text = read(project)
    old = f'INFOPLIST_KEY_CFBundleDisplayName = "{UPSTREAM_NAME}";'
    quoted = name if re.fullmatch(r"[A-Za-z0-9_.]+", name) else '"' + name.replace('"', '\\"') + '"'
    count = text.count(old)
    if count:
        write(project, text.replace(old, f"INFOPLIST_KEY_CFBundleDisplayName = {quoted};"))
        notes.append(f"set CFBundleDisplayName to {name!r} in {count} build configurations")
    return notes or [f"app name already {name!r}"]


def set_identity(apple, team, bundle_id):
    """Signs with your team and your identifiers. Every bundle ID, App Group and iCloud
    container upstream derives from BASE_PACKAGE_IDENTIFIER, so changing it (plus the
    team) moves the whole app off the upstream author's identity."""
    path = os.path.join(apple, "sing-box.xcodeproj", "project.pbxproj")
    text = read(path)
    notes = []
    if team:
        if not re.fullmatch(r"[A-Z0-9]{10}", team):
            fail(f"--team {team!r} is not a 10-character Apple team ID")
        pattern = re.compile(r'("?DEVELOPMENT_TEAM(?:\[sdk=[^\]]*\])?"? = )(?!"")[A-Z0-9"]+;')
        text, count = pattern.subn(lambda m: f"{m.group(1)}{team};", text)
        notes.append(f"signing team set to {team}" if count else "signing team already set")
    if bundle_id:
        if not re.fullmatch(r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+", bundle_id):
            fail(f"--bundle-id {bundle_id!r} is not a reverse-DNS identifier")
        text, count = re.subn(r"(BASE_PACKAGE_IDENTIFIER = )[^;]+;", lambda m: f"{m.group(1)}{bundle_id};", text)
        notes.append(f"bundle ID prefix set to {bundle_id} (App Group group.{bundle_id}, iCloud iCloud.{bundle_id})")
    write(path, text)
    if not team or not bundle_id:
        notes.append("WARNING: without --team and --bundle-id the project still signs as the upstream author")
    return notes


def copy_sources(apple):
    for folder in ["SFI", "MacLibrary"]:
        target = os.path.join(apple, folder, "SkywaveIntegration")
        os.makedirs(target, exist_ok=True)
        for name in INTEGRATION_FILES:
            shutil.copyfile(os.path.join(HERE, "Apple", name), os.path.join(target, name))
    return f"copied {len(INTEGRATION_FILES)} integration files into SFI/ and MacLibrary/ (synchronized groups)"


BRANDING = os.path.join(os.path.dirname(HERE), "Branding")

# (source under Branding/, destination under <apple>/). Every upstream icon carries the
# upstream mark, so all of them are replaced; nothing may look first-party.
ICON_TARGETS = [
    ("ios/AppIcon.appiconset", "SFI/Assets.xcassets/AppIcon.appiconset"),
    ("ios/AppIcon.appiconset", "WidgetExtension/Assets.xcassets/AppIcon.appiconset"),
    ("ios/AppIcon.appiconset", "ActionExtension/Assets.xcassets/AppIcon.appiconset"),
    ("mac/AppIcon.appiconset", "MacLibrary/Assets.xcassets/AppIcon.appiconset"),
    ("mac/AppIcon.icon", "MacLibrary/AppIcon.icon"),
    ("mac/AppIcon.icns", "MacLibrary/Icons/AppIcon.icns"),
    ("mac/MenuIcon.imageset", "MacLibrary/Assets.xcassets/MenuIcon.imageset"),
]
ICON_REMOVALS = ["MacLibrary/Assets.xcassets/MenuIcon.symbolset"]


def tree_digest(path):
    """Cheap content fingerprint of a file or folder, for idempotency reporting."""
    import hashlib
    digest = hashlib.sha256()
    if os.path.isfile(path):
        with open(path, "rb") as handle:
            digest.update(handle.read())
    elif os.path.isdir(path):
        for root, _, files in sorted(os.walk(path)):
            for name in sorted(files):
                digest.update(os.path.relpath(os.path.join(root, name), path).encode())
                with open(os.path.join(root, name), "rb") as handle:
                    digest.update(handle.read())
    return digest.hexdigest()


def install_icons(apple):
    changed = []
    pairs = list(ICON_TARGETS)
    for name in sorted(os.listdir(os.path.join(BRANDING, "ios"))):
        if name.startswith("AppIcon-"):  # per-skin alternate icons (iOS)
            pairs.append((f"ios/{name}", f"SFI/Assets.xcassets/{name}"))
    for source, destination in pairs:
        src, dst = os.path.join(BRANDING, source), os.path.join(apple, destination)
        if not os.path.exists(os.path.dirname(dst)):
            continue  # target not present in this checkout
        if tree_digest(src) == tree_digest(dst):
            continue
        if os.path.isdir(dst):
            shutil.rmtree(dst)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copyfile(src, dst)
        changed.append(destination)
    for removal in ICON_REMOVALS:
        path = os.path.join(apple, removal)
        if os.path.exists(path):
            shutil.rmtree(path)
            changed.append(f"removed {removal}")
    if not changed:
        return ["Skywave icons already installed"]
    return [f"installed Skywave icons ({len(changed)} items: app, alternates, widget, share, Mac, menu bar)"]


# ---------------------------------------------------------------------------
# project.pbxproj


class Project:
    def __init__(self, path):
        self.path = path
        self.text = read(path)
        self.used = set(re.findall(r"\b([0-9A-F]{24})\b", self.text))

    def new_id(self):
        while True:
            value = "5B5B" + "".join(random.choice("0123456789ABCDEF") for _ in range(20))
            if value not in self.used:
                self.used.add(value)
                return value

    def add_to_section(self, section, entry):
        end = f"/* End {section} section */"
        if end in self.text:
            self.text = self.text.replace(end, entry + end, 1)
        else:
            marker = "/* Begin PBXFileReference section */"
            block = f"/* Begin {section} section */\n{entry}/* End {section} section */\n\n"
            self.text = self.text.replace(marker, block + marker, 1)

    def object_block(self, object_id):
        match = re.search(rf"\n\t\t{object_id}(?: /\* [^\n]*? \*/)? = \{{\n(.*?)\n\t\t\}};", self.text, re.S)
        if not match:
            fail(f"object {object_id} not found")
        return match

    def append_to_list(self, object_id, key, line):
        """Adds `line` to the `key = ( … );` list of an object, creating the list if needed."""
        match = self.object_block(object_id)
        block = match.group(0)
        list_match = re.search(rf"(\t+){re.escape(key)} = \(\n(.*?)(\t+)\);", block, re.S)
        if list_match:
            if line.strip() in list_match.group(2):
                return
            indent = list_match.group(1) + "\t"
            new_list = list_match.group(0).replace(
                f"{list_match.group(3)});", f"{indent}{line},\n{list_match.group(3)});", 1
            )
            new_block = block.replace(list_match.group(0), new_list, 1)
        else:
            new_block = block.replace("\n\t\t};", f"\n\t\t\t{key} = (\n\t\t\t\t{line},\n\t\t\t);\n\t\t}};", 1)
        self.text = self.text.replace(block, new_block, 1)

    def target(self, name):
        match = re.search(rf"\t\t([0-9A-F]{{24}}) /\* {re.escape(name)} \*/ = \{{\n\t\t\tisa = PBXNativeTarget;(.*?)\n\t\t\}};", self.text, re.S)
        if not match:
            fail(f"target {name} not found")
        return match.group(1), match.group(2)

    def build_phase(self, target_name, isa):
        _, body = self.target(target_name)
        phases = re.search(r"buildPhases = \((.*?)\);", body, re.S).group(1)
        for phase_id in re.findall(r"([0-9A-F]{24})", phases):
            if f"isa = {isa};" in self.object_block(phase_id).group(0):
                return phase_id
        fail(f"{target_name} has no {isa}")

    def configurations(self, target_name):
        _, body = self.target(target_name)
        list_id = re.search(r"buildConfigurationList = ([0-9A-F]{24})", body).group(1)
        configs = re.search(r"buildConfigurations = \((.*?)\);", self.object_block(list_id).group(0), re.S).group(1)
        return re.findall(r"([0-9A-F]{24})", configs)

    def set_build_setting(self, config_id, key, value):
        block = self.object_block(config_id).group(0)
        if re.search(rf"\n\t\t\t\t{re.escape(key)} = ", block):
            new_block = re.sub(rf"(\n\t\t\t\t{re.escape(key)} = )[^;]*;", rf"\g<1>{value};", block, count=1)
        else:
            new_block = block.replace("buildSettings = {\n", f"buildSettings = {{\n\t\t\t\t{key} = {value};\n", 1)
        self.text = self.text.replace(block, new_block, 1)

    def save(self):
        write(self.path, self.text)


def patch_project(apple, local_path, url, branch):
    project = Project(os.path.join(apple, "sing-box.xcodeproj", "project.pbxproj"))
    if f'"{MARK}"' in project.text:
        return ["project.pbxproj already patched"]
    notes = []

    # Package reference.
    package_id = project.new_id()
    if local_path:
        target = os.path.realpath(local_path)
        relative = os.path.relpath(target, os.path.realpath(apple))
        if relative.count("..") > 3:
            relative = target  # far apart: an absolute path is clearer
        project.add_to_section(
            "XCLocalSwiftPackageReference",
            f'\t\t{package_id} /* XCLocalSwiftPackageReference "{MARK}" */ = {{\n'
            f"\t\t\tisa = XCLocalSwiftPackageReference;\n"
            f'\t\t\trelativePath = "{relative}";\n'
            f"\t\t}};\n",
        )
        package_comment = f'XCLocalSwiftPackageReference "{MARK}"'
        notes.append(f"added local package {relative}")
    else:
        project.add_to_section(
            "XCRemoteSwiftPackageReference",
            f'\t\t{package_id} /* XCRemoteSwiftPackageReference "{MARK}" */ = {{\n'
            f"\t\t\tisa = XCRemoteSwiftPackageReference;\n"
            f'\t\t\trepositoryURL = "{url}";\n'
            f"\t\t\trequirement = {{\n"
            f"\t\t\t\tbranch = {branch};\n"
            f"\t\t\t\tkind = branch;\n"
            f"\t\t\t}};\n"
            f"\t\t}};\n",
        )
        package_comment = f'XCRemoteSwiftPackageReference "{MARK}"'
        notes.append(f"added package {url} ({branch})")
    project_id = re.search(r"\t\t([0-9A-F]{24}) /\* Project object \*/ = \{", project.text).group(1)
    project.append_to_list(project_id, "packageReferences", f"{package_id} /* {package_comment} */")

    # Products → targets.
    for product, target_name in [("Skywave", "SFI"), ("Skywave", "MacLibrary"), ("SkywaveWidgets", "WidgetExtension")]:
        dependency_id = project.new_id()
        project.add_to_section(
            "XCSwiftPackageProductDependency",
            f"\t\t{dependency_id} /* {product} */ = {{\n"
            f"\t\t\tisa = XCSwiftPackageProductDependency;\n"
            f"\t\t\tpackage = {package_id} /* {package_comment} */;\n"
            f"\t\t\tproductName = {product};\n"
            f"\t\t}};\n",
        )
        build_file_id = project.new_id()
        project.add_to_section(
            "PBXBuildFile",
            f"\t\t{build_file_id} /* {product} in Frameworks */ = {{isa = PBXBuildFile; productRef = {dependency_id} /* {product} */; }};\n",
        )
        target_id, _ = project.target(target_name)
        project.append_to_list(target_id, "packageProductDependencies", f"{dependency_id} /* {product} */")
        frameworks = project.build_phase(target_name, "PBXFrameworksBuildPhase")
        project.append_to_list(frameworks, "files", f"{build_file_id} /* {product} in Frameworks */")
        notes.append(f"linked {product} to {target_name}")

    # Deployment targets: Liquid Glass and the skins need iOS 26 / macOS 26.
    for target_name in IOS_TARGETS:
        for config in project.configurations(target_name):
            project.set_build_setting(config, "IPHONEOS_DEPLOYMENT_TARGET", "26.0")
    for target_name in MAC_TARGETS:
        for config in project.configurations(target_name):
            project.set_build_setting(config, "MACOSX_DEPLOYMENT_TARGET", "26.0")
    notes.append("raised deployment targets to iOS 26.0 / macOS 26.0 for " + ", ".join(IOS_TARGETS + MAC_TARGETS))

    project.save()
    return notes


def main():
    parser = argparse.ArgumentParser(description="Wire Skywave into the sing-box Apple client.")
    parser.add_argument("apple", help="path to sing-box/clients/apple")
    parser.add_argument("--local", help="use a local Skywave checkout instead of GitHub")
    parser.add_argument("--url", default=DEFAULT_URL, help="Skywave repository URL")
    parser.add_argument("--branch", default="main", help="Skywave branch")
    parser.add_argument("--team", help="your 10-character Apple Developer team ID")
    parser.add_argument("--bundle-id", help="your bundle ID prefix, e.g. io.github.you.skywave")
    parser.add_argument("--app-name", default="Skywave",
                        help="product name that replaces the upstream name in display names and visible labels (default: Skywave)")
    args = parser.parse_args()

    apple = os.path.abspath(args.apple)
    if not os.path.exists(os.path.join(apple, "sing-box.xcodeproj", "project.pbxproj")):
        fail(f"{apple} does not look like sing-box/clients/apple")

    steps = [
        copy_sources(apple),
        patch_import_request(apple),
        patch_ios_main_view(apple),
        patch_mac_main_view(apple),
        patch_widget_bundle(apple),
        patch_info_plist(apple),
    ]
    steps += patch_project(apple, args.local, args.url, args.branch)
    steps += install_icons(apple)
    steps += set_identity(apple, args.team, args.bundle_id)
    if args.app_name:
        steps += rename_app(apple, args.app_name)
    for step in steps:
        print(f"  • {step}")
    print("Done. Open sing-box.xcodeproj or build with xcodebuild as usual.")


if __name__ == "__main__":
    main()

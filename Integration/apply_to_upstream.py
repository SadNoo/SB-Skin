#!/usr/bin/env python3
"""
Wire SB-Skin into a checkout of the sing-box Apple client.

    python3 Integration/apply_to_upstream.py /path/to/sing-box/clients/apple
    python3 Integration/apply_to_upstream.py /path/to/sing-box/clients/apple --local /path/to/SB-Skin

What it does (idempotent; running it twice changes nothing the second time):

1. Copies Integration/Apple/*.swift into <apple>/SFI/SBSkinIntegration/ and
   <apple>/MacLibrary/SBSkinIntegration/ (both are file-system synchronized groups, so the
   files join the SFI and MacLibrary targets without project edits).
2. Patches three upstream Swift files so the skins replace the root navigation:
   - SFI/MainView.swift            (iOS / iPadOS)
   - MacLibrary/MainView.swift     (macOS)
   - WidgetExtension/ExtensionBundle.swift (adds the SB-Skin widgets and Live Activity)
3. Edits sing-box.xcodeproj/project.pbxproj:
   - adds the SB-Skin Swift package (GitHub by default, or --local path),
   - links SBSkin to SFI and MacLibrary, SBSkinWidgets to WidgetExtension,
   - raises the deployment target of those targets (and the macOS apps) to 26.0.
4. Enables Live Activities in SFI/Info.plist.
5. With --app-name NAME, replaces the upstream product name in the app display names and
   in the few visible literals (Mac window title, Quit menu, menu bar label, VPN server
   label, Files app domain, Control Center toggle).

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
MARK = "SB-Skin"
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


def patch_ios_main_view(apple):
    path = os.path.join(apple, "SFI", "MainView.swift")
    text = read(path)
    if "SkinIntegrationRoot()" in text:
        return "SFI/MainView.swift already patched"
    anchor = "    private var tabViewContent: some View {\n"
    if anchor not in text:
        fail("SFI/MainView.swift: tabViewContent not found; upstream changed, patch by hand (see INTEGRATION.md)")
    text = text.replace(
        anchor,
        "    // SB-Skin: the skins replace the upstream tab view.\n"
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
        anchor + "        // SB-Skin: widget and Live Activity links.\n"
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
    text = text[:split] + "SkinIntegrationRoot() // SB-Skin: the skins replace the sidebar layout." + text[detail_close + 1:]
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
    text = text.replace("import SwiftUI\n", "import SBSkinWidgets\nimport SwiftUI\n", 1)
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


def copy_sources(apple):
    for folder in ["SFI", "MacLibrary"]:
        target = os.path.join(apple, folder, "SBSkinIntegration")
        os.makedirs(target, exist_ok=True)
        for name in INTEGRATION_FILES:
            shutil.copyfile(os.path.join(HERE, "Apple", name), os.path.join(target, name))
    return f"copied {len(INTEGRATION_FILES)} integration files into SFI/ and MacLibrary/ (synchronized groups)"


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
    for product, target_name in [("SBSkin", "SFI"), ("SBSkin", "MacLibrary"), ("SBSkinWidgets", "WidgetExtension")]:
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
    parser = argparse.ArgumentParser(description="Wire SB-Skin into the sing-box Apple client.")
    parser.add_argument("apple", help="path to sing-box/clients/apple")
    parser.add_argument("--local", help="use a local SB-Skin checkout instead of GitHub")
    parser.add_argument("--url", default=DEFAULT_URL, help="SB-Skin repository URL")
    parser.add_argument("--branch", default="main", help="SB-Skin branch")
    parser.add_argument("--app-name", help="replace the upstream product name in display names and visible labels")
    args = parser.parse_args()

    apple = os.path.abspath(args.apple)
    if not os.path.exists(os.path.join(apple, "sing-box.xcodeproj", "project.pbxproj")):
        fail(f"{apple} does not look like sing-box/clients/apple")

    steps = [
        copy_sources(apple),
        patch_ios_main_view(apple),
        patch_mac_main_view(apple),
        patch_widget_bundle(apple),
        patch_info_plist(apple),
    ]
    steps += patch_project(apple, args.local, args.url, args.branch)
    if args.app_name:
        steps += rename_app(apple, args.app_name)
    for step in steps:
        print(f"  • {step}")
    print("Done. Open sing-box.xcodeproj or build with xcodebuild as usual.")


if __name__ == "__main__":
    main()

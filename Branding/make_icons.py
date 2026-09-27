#!/usr/bin/env python3
"""Generates every Skywave icon asset from one drawing.

The mark: a tuning knob under an arc of sky. The pointer is turned toward a station on the
arc — tuned in to a signal that travels by the sky, which is what a "skywave" is.

    pip install cairosvg pillow      (cairosvg needs the cairo library: brew install cairo)
    python3 Branding/make_icons.py

Outputs (all under Branding/, committed so builds need no Python):
    ios/AppIcon.appiconset           iOS / iPadOS icon, light + dark + tinted
    ios/AppIcon-<Skin>.appiconset    alternate icons, one per skin
    mac/AppIcon.appiconset           macOS icon at every size
    mac/AppIcon.icon                 macOS 26 Icon Composer icon (light / dark / tinted)
    mac/AppIcon.icns                 legacy icns
    mac/MenuIcon.imageset            menu bar template icon
    svg/*.svg                        the source drawings

SPDX-License-Identifier: GPL-3.0-or-later
"""

import io
import json
import math
import os
import shutil
import subprocess
import tempfile

import cairosvg
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE = 1024
CX, CY = 512, 572
ARC_R, KNOB_R = 360, 250
POINTER = -62  # degrees, 0 = east, clockwise positive (SVG)


def point(r, degrees):
    a = math.radians(degrees)
    return CX + r * math.cos(a), CY + r * math.sin(a)


def mark(background, arc, knob, accent, ring="#ffffff", ring_opacity=0.08):
    """The full icon drawing as SVG. `background=None` leaves it transparent."""
    x0, y0 = point(ARC_R, -160)
    x1, y1 = point(ARC_R, -20)
    sx, sy = point(ARC_R, POINTER)
    px, py = point(KNOB_R * 0.66, POINTER)
    qx, qy = point(KNOB_R * 0.24, POINTER)
    parts = []
    if background:
        parts.append(f'<rect width="{SIZE}" height="{SIZE}" fill="{background}"/>')
    parts.append(
        f'<path d="M{x0:.1f} {y0:.1f} A{ARC_R} {ARC_R} 0 0 1 {x1:.1f} {y1:.1f}" fill="none" '
        f'stroke="{arc}" stroke-width="44" stroke-linecap="round"/>'
    )
    # Station: a dot on the arc with a gap around it.
    parts.append(f'<circle cx="{sx:.1f}" cy="{sy:.1f}" r="46" fill="{background}"/>')
    parts.append(f'<circle cx="{sx:.1f}" cy="{sy:.1f}" r="30" fill="{accent}"/>')
    parts.append(f'<circle cx="{CX}" cy="{CY}" r="{KNOB_R}" fill="{knob}"/>')
    parts.append(
        f'<circle cx="{CX}" cy="{CY}" r="212" fill="none" stroke="{ring}" '
        f'stroke-opacity="{ring_opacity}" stroke-width="14"/>'
    )
    parts.append(
        f'<line x1="{qx:.1f}" y1="{qy:.1f}" x2="{px:.1f}" y2="{py:.1f}" stroke="{accent}" '
        f'stroke-width="40" stroke-linecap="round"/>'
    )
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">{"".join(parts)}</svg>'


def layer(kind, color):
    """One element of the mark on a transparent canvas (for Icon Composer layers)."""
    x0, y0 = point(ARC_R, -160)
    x1, y1 = point(ARC_R, -20)
    sx, sy = point(ARC_R, POINTER)
    px, py = point(KNOB_R * 0.66, POINTER)
    qx, qy = point(KNOB_R * 0.24, POINTER)
    if kind == "sky":
        body = (
            f'<mask id="m"><rect width="{SIZE}" height="{SIZE}" fill="#fff"/>'
            f'<circle cx="{sx:.1f}" cy="{sy:.1f}" r="46" fill="#000"/></mask>'
            f'<path mask="url(#m)" d="M{x0:.1f} {y0:.1f} A{ARC_R} {ARC_R} 0 0 1 {x1:.1f} {y1:.1f}" '
            f'fill="none" stroke="{color}" stroke-width="44" stroke-linecap="round"/>'
        )
    elif kind == "knob":
        body = f'<circle cx="{CX}" cy="{CY}" r="{KNOB_R}" fill="{color}"/>'
    else:  # signal: station + pointer
        body = (
            f'<circle cx="{sx:.1f}" cy="{sy:.1f}" r="30" fill="{color}"/>'
            f'<line x1="{qx:.1f}" y1="{qy:.1f}" x2="{px:.1f}" y2="{py:.1f}" stroke="{color}" '
            f'stroke-width="40" stroke-linecap="round"/>'
        )
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">{body}</svg>'


def tinted_svg():
    """Grayscale on transparent; the system supplies the background and the tint."""
    x0, y0 = point(ARC_R, -160)
    x1, y1 = point(ARC_R, -20)
    sx, sy = point(ARC_R, POINTER)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
        f'<mask id="m"><rect width="{SIZE}" height="{SIZE}" fill="#fff"/>'
        f'<circle cx="{sx:.1f}" cy="{sy:.1f}" r="46" fill="#000"/></mask>'
        f'<path mask="url(#m)" d="M{x0:.1f} {y0:.1f} A{ARC_R} {ARC_R} 0 0 1 {x1:.1f} {y1:.1f}" '
        f'fill="none" stroke="#b8b8b8" stroke-width="44" stroke-linecap="round"/>'
        + layer("knob", "#4a4a4a").split(">", 1)[1].rsplit("</svg>", 1)[0]
        + layer("signal", "#ffffff").split(">", 1)[1].rsplit("</svg>", 1)[0]
        + "</svg>"
    )


# Skin colorways: background, arc, knob, accent (pointer + station).
BRAND = ("#F3EEE6", "#1D1D22", "#1D1D22", "#FF5A1F")
DARK = ("#141417", "#F3EEE6", "#2B2B31", "#FF5A1F")
SKINS = {
    "Native": ("#F2F4F8", "#1C1C1E", "#1C1C1E", "#0A84FF"),
    "Instrument": ("#0B1220", "#DCE6F2", "#1B2638", "#38BDF8"),
    "Focus": ("#E7EFEA", "#23463A", "#23463A", "#7CD4A3"),
    "Places": ("#DCE5EE", "#1E2A36", "#1E2A36", "#E8552D"),
    "Lens": ("#EEF0FF", "#1E1B4B", "#1E1B4B", "#8B8BFF"),
    "Sentence": ("#F3EDE3", "#2A2521", "#2A2521", "#D0543B"),
    "Radio": BRAND,
    "Bento": ("#EFEFEF", "#111111", "#111111", "#E5231B"),
    "Ink": ("#EDEBE6", "#141414", "#141414", "#8C8C8C"),
    "Mart": ("#FFD84D", "#231C16", "#D93D24", "#231C16"),
}


def png(svg, size=SIZE, opaque=True):
    data = cairosvg.svg2png(bytestring=svg.encode(), output_width=size, output_height=size)
    image = Image.open(io.BytesIO(data))
    if opaque:
        image = image.convert("RGB")  # App Store icons must not have alpha
    out = io.BytesIO()
    image.save(out, "PNG", optimize=True)
    return out.getvalue()


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    mode = "wb" if isinstance(data, bytes) else "w"
    with open(path, mode) as handle:
        handle.write(data)


def contents(images):
    return json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"


def ios_iconset(path, light, dark=None, tinted=None):
    images = [{"filename": "1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    write(os.path.join(path, "1024.png"), png(light))
    for name, svg, opaque in (("dark", dark, True), ("tinted", tinted, False)):
        if svg is None:
            continue
        write(os.path.join(path, f"1024-{name}.png"), png(svg, opaque=opaque))
        images.append({
            "appearances": [{"appearance": "luminosity", "value": name}],
            "filename": f"1024-{name}.png", "idiom": "universal", "platform": "ios", "size": "1024x1024",
        })
    write(os.path.join(path, "Contents.json"), contents(images))


def mac_square(svg):
    """macOS icons are not masked by the system: draw the rounded plate with margins."""
    inner = svg.split(">", 1)[1].rsplit("</svg>", 1)[0]
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
        f'<defs><clipPath id="c"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath></defs>'
        f'<g clip-path="url(#c)" transform="translate(100 100) scale({824 / SIZE})">{inner}</g></svg>'
    )


def main():
    for folder in ("ios", "mac", "svg"):
        shutil.rmtree(os.path.join(HERE, folder), ignore_errors=True)

    light, dark, tinted = mark(*BRAND), mark(*DARK, ring_opacity=0.1), tinted_svg()
    write(os.path.join(HERE, "svg/skywave.svg"), light)
    write(os.path.join(HERE, "svg/skywave-dark.svg"), dark)
    write(os.path.join(HERE, "svg/skywave-tinted.svg"), tinted)

    ios_iconset(os.path.join(HERE, "ios/AppIcon.appiconset"), light, dark, tinted)
    for skin, colors in SKINS.items():
        svg = mark(*colors, ring_opacity=0.1 if colors[0].startswith("#0") else 0.08)
        write(os.path.join(HERE, f"svg/skywave-{skin.lower()}.svg"), svg)
        if colors != BRAND:  # the primary icon already wears the Radio colors
            ios_iconset(os.path.join(HERE, f"ios/AppIcon-{skin}.appiconset"), svg)

    # macOS asset catalog icon, every size.
    mac_light = mac_square(light)
    images = []
    base = os.path.join(HERE, "mac/AppIcon.appiconset")
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            name = f"icon_{points}x{points}{'@2x' if scale == 2 else ''}.png"
            write(os.path.join(base, name), png(mac_light, points * scale, opaque=False))
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{points}x{points}"})
    write(os.path.join(base, "Contents.json"), contents(images))

    # Legacy icns from the same renders.
    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        shutil.copytree(base, iconset, ignore=shutil.ignore_patterns("Contents.json"))
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(HERE, "mac/AppIcon.icns")], check=True)

    # macOS 26 Icon Composer icon: three layers so the system can add depth and glass.
    icon = os.path.join(HERE, "mac/AppIcon.icon")
    write(os.path.join(icon, "Assets/sky.png"), png(layer("sky", BRAND[1]), opaque=False))
    write(os.path.join(icon, "Assets/sky-dark.png"), png(layer("sky", DARK[1]), opaque=False))
    write(os.path.join(icon, "Assets/knob.png"), png(layer("knob", BRAND[2]), opaque=False))
    write(os.path.join(icon, "Assets/knob-dark.png"), png(layer("knob", DARK[2]), opaque=False))
    write(os.path.join(icon, "Assets/signal.png"), png(layer("signal", BRAND[3]), opaque=False))

    def srgb(hex_color):
        r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
        return f"srgb:{r:.5f},{g:.5f},{b:.5f},1.00000"

    def group(name, image, dark_image=None):
        entry = {"glass": False, "image-name": image, "name": name}
        if dark_image:
            entry["image-name-specializations"] = [{"appearance": "dark", "value": dark_image}]
        return {"layers": [entry], "shadow": {"kind": "neutral", "opacity": 0.4}, "translucency": {"enabled": False, "value": 0.5}}

    manifest = {
        "fill": {"solid": srgb(BRAND[0])},
        "fill-specializations": [{"appearance": "dark", "value": {"solid": srgb(DARK[0])}}],
        "groups": [
            group("signal", "signal.png"),
            group("knob", "knob.png", "knob-dark.png"),
            group("sky", "sky.png", "sky-dark.png"),
        ],
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }
    write(os.path.join(icon, "icon.json"), json.dumps(manifest, indent=2) + "\n")

    # Menu bar: a template glyph (knob + sky), drawn black on transparent.
    glyph = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 1024 1024">'
        + layer("sky", "#000").split(">", 1)[1].rsplit("</svg>", 1)[0]
        + f'<circle cx="{CX}" cy="{CY}" r="{KNOB_R}" fill="none" stroke="#000" stroke-width="70"/>'
        + layer("signal", "#000").split(">", 1)[1].rsplit("</svg>", 1)[0]
        + "</svg>"
    )
    menu = os.path.join(HERE, "mac/MenuIcon.imageset")
    write(os.path.join(menu, "MenuIcon.svg"), glyph)
    write(os.path.join(menu, "Contents.json"), json.dumps({
        "images": [{"filename": "MenuIcon.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
    }, indent=2) + "\n")
    sync_demo()
    print("icons written to", HERE)


def sync_demo():
    """The demo app gets the same icons: iOS set plus the Mac sizes in one AppIcon."""
    catalog = os.path.join(os.path.dirname(HERE), "Demo", "App", "Assets.xcassets")
    shutil.rmtree(catalog, ignore_errors=True)
    write(os.path.join(catalog, "Contents.json"), json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    for name in sorted(os.listdir(os.path.join(HERE, "ios"))):
        shutil.copytree(os.path.join(HERE, "ios", name), os.path.join(catalog, name))
    primary = os.path.join(catalog, "AppIcon.appiconset")
    mac = os.path.join(HERE, "mac", "AppIcon.appiconset")
    with open(os.path.join(primary, "Contents.json")) as handle:
        manifest = json.load(handle)
    with open(os.path.join(mac, "Contents.json")) as handle:
        manifest["images"] += json.load(handle)["images"]
    for name in os.listdir(mac):
        if name.endswith(".png"):
            shutil.copy(os.path.join(mac, name), primary)
    write(os.path.join(primary, "Contents.json"), json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()

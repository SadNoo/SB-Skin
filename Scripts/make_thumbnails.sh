#!/bin/zsh
# Regenerates the skin picker thumbnails (Sources/Skywave/Resources/Thumbnails) from the demo
# app: every skin, in English, Simplified and Traditional Chinese, frozen sample data, a clean
# status bar and light appearance.
#
#   Scripts/make_thumbnails.sh <simulator UDID or name>     (an iPhone, e.g. "iPhone 17 Pro")
#
# Needs Xcode and xcodegen. Takes a few minutes.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

DEVICE=${1:?usage: $0 <simulator UDID or name>}
ROOT=${0:A:h:h}
OUT=$ROOT/Sources/Skywave/Resources/Thumbnails
BUNDLE=io.github.sadnoo.skywave.demo
DERIVED=$(mktemp -d)
SHOT=$DERIVED/shot.png

SKINS=(${(f)"$(grep -E '^    case [a-z]+$' $ROOT/Sources/SkywaveShared/SkinID.swift | awk '{print $2}')"})
LANGUAGES=(en zh-Hans zh-Hant)

echo "Building the demo app…"
(cd $ROOT/Demo && xcodegen -q)
if [[ $DEVICE == *-*-*-*-* ]]; then DESTINATION="id=$DEVICE"; else DESTINATION="name=$DEVICE"; fi
xcodebuild -project $ROOT/Demo/SkywaveDemo.xcodeproj -scheme SkywaveDemo \
    -destination "platform=iOS Simulator,$DESTINATION" \
    -derivedDataPath $DERIVED build -quiet
APP=$DERIVED/Build/Products/Debug-iphonesimulator/SkywaveDemo.app

xcrun simctl boot $DEVICE 2>/dev/null || true
xcrun simctl bootstatus $DEVICE -b >/dev/null
xcrun simctl install $DEVICE $APP
xcrun simctl ui $DEVICE appearance light
xcrun simctl status_bar $DEVICE override --time 9:41 --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularMode notSupported >/dev/null
trap 'xcrun simctl status_bar $DEVICE clear >/dev/null 2>&1; rm -rf $DERIVED' EXIT

running() { xcrun simctl spawn $DEVICE launchctl list 2>/dev/null | grep -q "UIKitApplication:$BUNDLE" }

# The first launch after an install is slow; get it out of the way.
xcrun simctl launch $DEVICE $BUNDLE -skywave-scenario frozen >/dev/null
sleep 12

mkdir -p $OUT
previous=""
for lang in $LANGUAGES; do
    for skin in $SKINS; do
        xcrun simctl terminate $DEVICE $BUNDLE >/dev/null 2>&1 || true
        for _ in {1..20}; do running || break; sleep 0.5; done
        xcrun simctl spawn $DEVICE defaults write $BUNDLE skywave.skin -string $skin
        xcrun simctl spawn $DEVICE defaults write $BUNDLE skywave.hasChosenSkin -bool YES
        xcrun simctl launch $DEVICE $BUNDLE -skywave-skin $skin -skywave-scenario frozen \
            -AppleLanguages "($lang)" -AppleLocale ${lang/-/_} >/dev/null
        sleep 7
        for attempt in 1 2 3; do
            xcrun simctl io $DEVICE screenshot $SHOT >/dev/null 2>&1
            digest=$(md5 -q $SHOT)
            [[ $digest != $previous ]] && break
            sleep 4  # the previous app was still on screen
        done
        previous=$digest
        sips -s format jpeg -s formatOptions 72 --resampleWidth 480 $SHOT --out $OUT/thumb-$skin-$lang.jpg >/dev/null
        echo "  thumb-$skin-$lang.jpg"
    done
done
xcrun simctl terminate $DEVICE $BUNDLE >/dev/null 2>&1 || true
echo "Done: $(ls $OUT | wc -l | tr -d ' ') thumbnails in $OUT"

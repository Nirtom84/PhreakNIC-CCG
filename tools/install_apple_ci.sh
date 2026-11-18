#!/usr/bin/env bash
# Used only by Apple builds on GitHub-hosted macOS runners.
set -euo pipefail
: "${RUNNER_TEMP:?Run this helper in GitHub Actions}"
: "${GITHUB_ENV:?Run this helper in GitHub Actions}"
: "${GODOT_MAC_SHA256:?Missing pinned editor checksum}"
: "${GODOT_TEMPLATES_SHA256:?Missing pinned template checksum}"
mkdir -p "$RUNNER_TEMP/godot-apple"
cd "$RUNNER_TEMP/godot-apple"
curl -fLsS --retry 3 -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_macos.universal.zip
echo "$GODOT_MAC_SHA256  godot.zip" | shasum -a 256 -c -
unzip -q godot.zip
curl -fLsS --retry 3 -o templates.tpz https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz
echo "$GODOT_TEMPLATES_SHA256  templates.tpz" | shasum -a 256 -c -
unzip -q templates.tpz templates/macos.zip templates/ios.zip templates/version.txt
mkdir -p "$HOME/Library/Application Support/Godot/export_templates/4.7.1.stable"
cp templates/* "$HOME/Library/Application Support/Godot/export_templates/4.7.1.stable/"
echo "GODOT=$RUNNER_TEMP/godot-apple/Godot.app/Contents/MacOS/Godot" >> "$GITHUB_ENV"

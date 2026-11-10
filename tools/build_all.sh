#!/usr/bin/env bash
# Builds the Linux, Windows, Android and Web versions into build/.
# Needs: Godot 4.7.1 export templates, JDK 17 and the Android SDK (see README "Building").
# Usage: tools/build_all.sh [linux|windows|android|web|release ...]   (no arguments = all four, then release)
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/.local/bin/godot4.7.1}"
export JAVA_HOME="${JAVA_HOME:-$HOME/.local/opt/jdk-17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(linux windows android web release)

# Keep Godot from importing the build output (it would add .import files and pack build artefacts).
mkdir -p build && touch build/.gdignore
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

for target in "${targets[@]}"; do
	case "$target" in
		linux)
			mkdir -p build/linux
			"$GODOT" --headless --path . --export-release "Linux" "build/linux/PhreakNIC-CCG-v$VERSION.x86_64" ;;
		windows)
			mkdir -p build/windows
			"$GODOT" --headless --path . --export-release "Windows" "build/windows/PhreakNIC-CCG-v$VERSION.exe" ;;
		android)
			mkdir -p build/android
			# Debug-signed APK (installs by sideloading). A Play Store release needs a release keystore.
			"$GODOT" --headless --path . --export-debug "Android" "build/android/PhreakNIC-CCG-v$VERSION-debug.apk" ;;
		web)
			mkdir -p build/web
			"$GODOT" --headless --path . --export-release "Web" build/web/index.html ;;
		release)
			# Packages the builds made above under stable names for GitHub Release assets,
			# so README links to releases/latest/download/<name> keep working.
			mkdir -p build/release
			rm -f build/release/*
			(cd build/linux && zip -q -9 "../release/PhreakNIC-CCG-linux.zip" "PhreakNIC-CCG-v$VERSION.x86_64")
			(cd build/windows && zip -q -9 "../release/PhreakNIC-CCG-windows.zip" "PhreakNIC-CCG-v$VERSION.exe")
			cp "build/android/PhreakNIC-CCG-v$VERSION-debug.apk" "build/release/PhreakNIC-CCG-android.apk" ;;
		*) echo "Unknown target: $target (use linux, windows, android, web or release)" >&2; exit 1 ;;
	esac
done
ls -la build/*/

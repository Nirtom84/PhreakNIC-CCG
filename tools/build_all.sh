#!/usr/bin/env bash
# Builds the Linux, Windows, Android and Web versions into build/.
# Needs: Godot 4.7.1 export templates, JDK 17 and the Android SDK (see README "Building").
# Usage: tools/build_all.sh [linux|windows|android|web|server|release ...]   (no arguments = all four, then release)
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
		server)
			mkdir -p build/server
			"$GODOT" --headless --path . --export-release "Server" build/server/phreaknic-server.x86_64 ;;
		windows)
			mkdir -p build/windows
			"$GODOT" --headless --path . --export-release "Windows" "build/windows/PhreakNIC-CCG-v$VERSION.exe" ;;
		android)
			mkdir -p build/android
			# Release-signed with the project's keystore when ~/.config/phreaknic/android-signing.sh exists
			# (it loads the keystore path and password from ~/.tokens; nothing secret is in the repo).
			# Without it, falls back to a debug-signed APK for local testing.
			rm -f build/android/PhreakNIC-CCG-v$VERSION*.apk
			if [ -f "$HOME/.config/phreaknic/android-signing.sh" ]; then
				( source "$HOME/.config/phreaknic/android-signing.sh"
				  "$GODOT" --headless --path . --export-release "Android" "build/android/PhreakNIC-CCG-v$VERSION.apk" )
			else
				echo "No Android signing config; building a debug-signed APK." >&2
				"$GODOT" --headless --path . --export-debug "Android" "build/android/PhreakNIC-CCG-v$VERSION-debug.apk"
			fi ;;
		web)
			mkdir -p build/web
			"$GODOT" --headless --path . --export-release "Web" build/web/index.html
			# Same-origin helper for sharing the result card (the site CSP forbids eval).
			cp tools/web/share.js build/web/share.js ;;
		release)
			# Packages the builds made above under stable names for GitHub Release assets,
			# so README links to releases/latest/download/<name> keep working.
			mkdir -p build/release
			rm -f build/release/*
			(cd build/linux && zip -q -9 "../release/PhreakNIC-CCG-linux.zip" "PhreakNIC-CCG-v$VERSION.x86_64")
			(cd build/windows && zip -q -9 "../release/PhreakNIC-CCG-windows.zip" "PhreakNIC-CCG-v$VERSION.exe")
			apk="build/android/PhreakNIC-CCG-v$VERSION.apk"; [ -f "$apk" ] || apk="build/android/PhreakNIC-CCG-v$VERSION-debug.apk"
			cp "$apk" "build/release/PhreakNIC-CCG-android.apk"
			# Checksums so players can verify downloads (attach SHA256SUMS.txt to the GitHub Release).
			(cd build/release && sha256sum PhreakNIC-CCG-* > SHA256SUMS.txt) ;;
		*) echo "Unknown target: $target (use linux, windows, android, web, server or release)" >&2; exit 1 ;;
	esac
done
ls -la build/*/

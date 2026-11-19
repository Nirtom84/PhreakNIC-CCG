#!/usr/bin/env bash
# Builds the Linux, Windows, macOS, Android and Web versions into build/.
# Needs: Godot 4.7.1 and matching export templates; Android also needs JDK 17 and the Android SDK.
# Usage: tools/build_all.sh [linux|windows|macos|android|web|server|release|ios-project|ios|ios-simulator ...]
# No arguments = the five existing client builds, then release. iOS targets are opt-in.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/.local/bin/godot4.7.1}"
export JAVA_HOME="${JAVA_HOME:-$HOME/.local/opt/jdk-17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "Invalid project version" >&2; exit 1; }
BUILD_COMMIT="$(git rev-parse HEAD)"
BUILD_TREE=clean
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || BUILD_TREE=dirty
targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(linux windows macos android web release)

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
		macos)
			mkdir -p build/macos
			# Godot creates the .app bundle inside the ZIP and preserves executable permissions.
			# The preset uses built-in ad-hoc signing, so this also works on Linux without Apple credentials.
			"$GODOT" --headless --path . --export-release "macOS" "build/macos/PhreakNIC-CCG-v$VERSION.zip"
			(cd build/macos && shasum -a 256 "PhreakNIC-CCG-v$VERSION.zip" > SHA256SUMS.txt) ;;
		ios-project|ios|ios-simulator)
			GODOT="$GODOT" tools/build_ios.sh "$target" ;;
		android)
			mkdir -p build/android
			# Release-signed with the project's keystore when ~/.config/phreaknic/android-signing.sh exists
			# (it loads the keystore path and password from ~/.tokens; nothing secret is in the repo).
			# Without it, falls back to a debug-signed APK for local testing.
			rm -f "build/android/PhreakNIC-CCG-v${VERSION}"*.apk
			if [ -f "$HOME/.config/phreaknic/android-signing.sh" ]; then
				( source "$HOME/.config/phreaknic/android-signing.sh"
				  "$GODOT" --headless --path . --export-release "Android" "build/android/PhreakNIC-CCG-v$VERSION.apk" )
			else
				echo "No Android signing config; building a debug-signed APK." >&2
				"$GODOT" --headless --path . --export-debug "Android" "build/android/PhreakNIC-CCG-v$VERSION-debug.apk"
			fi ;;
		web)
			rm -rf -- build/web
			mkdir -p build/web
			"$GODOT" --headless --path . --export-release "Web" build/web/index.html
			# Same-origin helper for sharing the result card (the site CSP forbids eval).
			cp tools/web/share.js build/web/share.js
			mkdir -p build/web/music
			cp assets/music/*.ogg build/web/music/ ;;
		release)
			# Packages the builds made above under stable names for GitHub Release assets,
			# so README links to releases/latest/download/<name> keep working.
			# Players install the APK over the release-signed app, so a debug-signed one is
			# packaged only on request (ALLOW_DEBUG_APK=1, for local testing).
			apk="build/android/PhreakNIC-CCG-v$VERSION.apk"
			if [ ! -f "$apk" ]; then
				if [ "${ALLOW_DEBUG_APK:-}" != 1 ]; then
					echo "No release-signed $apk (is ~/.config/phreaknic/android-signing.sh missing?)." >&2
					echo "Refusing to package the debug-signed APK; set ALLOW_DEBUG_APK=1 to package it anyway." >&2
					exit 1
				fi
				apk="build/android/PhreakNIC-CCG-v$VERSION-debug.apk"
				echo "ALLOW_DEBUG_APK=1: packaging the debug-signed APK." >&2
			fi
			macos="build/macos/PhreakNIC-CCG-v$VERSION.zip"
			if [ ! -f "$macos" ]; then
				echo "No $macos; run tools/build_all.sh macos before packaging the release." >&2
				exit 1
			fi
			mkdir -p build/release
			rm -f build/release/*
			(cd build/linux && zip -q -9 "../release/PhreakNIC-CCG-linux.zip" "PhreakNIC-CCG-v$VERSION.x86_64")
			(cd build/windows && zip -q -9 "../release/PhreakNIC-CCG-windows.zip" "PhreakNIC-CCG-v$VERSION.exe")
			cp "$macos" "build/release/PhreakNIC-CCG-macos.zip"
			cp "$apk" "build/release/PhreakNIC-CCG-android.apk"
			# Checksums so players can verify downloads (attach SHA256SUMS.txt to the GitHub Release).
			(cd build/release && sha256sum PhreakNIC-CCG-* > SHA256SUMS.txt) ;;
		*) echo "Unknown target: $target (use linux, windows, macos, android, web, server, release, ios-project, ios or ios-simulator)" >&2; exit 1 ;;
	esac
	# The iOS targets all write into build/ios/.
	out="build/$target"; case "$target" in ios-project|ios|ios-simulator) out=build/ios ;; esac
	printf '%s\n%s\n' "$BUILD_COMMIT" "$BUILD_TREE" > "$out/BUILD_COMMIT"
done
ls -la build/*/

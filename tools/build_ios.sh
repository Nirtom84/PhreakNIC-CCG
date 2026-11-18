#!/usr/bin/env bash
# Export an Xcode project anywhere; compile an unsigned IPA or simulator app on macOS.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/.local/bin/godot4.7.1}"
target="${1:-ios-project}"
case "$target" in
	ios-project|ios|ios-simulator) ;;
	*) echo "Usage: tools/build_ios.sh [ios-project|ios|ios-simulator]" >&2; exit 1 ;;
esac
if [ "$target" != ios-project ]; then
	if [ "$(uname -s)" != Darwin ] || ! command -v xcodebuild >/dev/null; then
		echo "Compiling iOS requires macOS with Xcode. On Linux use ios-project or the Apple builds GitHub workflow." >&2
		exit 1
	fi
fi

VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
mkdir -p build/ios/project
touch build/.gdignore
"$GODOT" --headless --path . --export-release "iOS" "$PWD/build/ios/project/PhreakNICCCG.zip"
test -f build/ios/project/PhreakNICCCG.xcodeproj/project.pbxproj
test -s build/ios/project/PhreakNICCCG.pck

if [ "$target" = ios-project ]; then
	echo "Xcode project exported to build/ios/project/PhreakNICCCG.xcodeproj (no IPA compiled)."
	exit 0
fi

if [ "$target" = ios ]; then
	derived="$PWD/build/ios/device"
	xcodebuild -project build/ios/project/PhreakNICCCG.xcodeproj \
		-scheme PhreakNICCCG -configuration Release -sdk iphoneos \
		-destination 'generic/platform=iOS' -derivedDataPath "$derived" \
		CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build
	test -x "$derived/Build/Products/Release-iphoneos/PhreakNICCCG.app/PhreakNICCCG"
	# This IPA is intentionally unsigned. Signing/provisioning is required before device installation.
	stage="$(mktemp -d "$PWD/build/ios/ipa.XXXXXX")"
	trap 'rm -rf "$stage"' EXIT
	mkdir "$stage/Payload"
	cp -R "$derived/Build/Products/Release-iphoneos/PhreakNICCCG.app" "$stage/Payload/"
	archive="$PWD/build/ios/PhreakNIC-CCG-v$VERSION-unsigned.ipa"
	rm -f "$archive"
	(cd "$stage" && zip -q -r -y "$archive" Payload)
	(cd build/ios && shasum -a 256 "PhreakNIC-CCG-v$VERSION-unsigned.ipa" > SHA256SUMS.txt)
	echo "Unsigned IPA: $archive (sign before installing on an iPhone or iPad)."
else
	xcodebuild -project build/ios/project/PhreakNICCCG.xcodeproj \
		-scheme PhreakNICCCG -configuration Release -sdk iphonesimulator \
		-destination 'generic/platform=iOS Simulator' -derivedDataPath "$PWD/build/ios/simulator" \
		ARCHS=x86_64 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build
	test -x build/ios/simulator/Build/Products/Release-iphonesimulator/PhreakNICCCG.app/PhreakNICCCG
	# Simulator installation needs an ad-hoc signed bundle; no Apple account is involved.
	codesign --force --sign - --timestamp=none build/ios/simulator/Build/Products/Release-iphonesimulator/PhreakNICCCG.app
	codesign --verify --deep --strict build/ios/simulator/Build/Products/Release-iphonesimulator/PhreakNICCCG.app
	echo "Simulator app: build/ios/simulator/Build/Products/Release-iphonesimulator/PhreakNICCCG.app"
fi

# macOS builds

The `macOS` Godot export preset produces one `.app` for Intel x86_64 and Apple Silicon arm64. Deployment targets are macOS 11 on Intel and macOS 13 on Apple Silicon. The game code, assets, bots and online protocol are shared with the other platforms.

## Build and package

Install Godot 4.7.1 and its matching standard export templates from the [official release](https://github.com/godotengine/godot/releases/tag/4.7.1-stable). Verify downloads against the release checksums. In Godot, use **Editor → Manage Export Templates → Install from File** to install the `.tpz` archive. On Linux, the exporter needs `macos.zip` in `~/.local/share/godot/export_templates/4.7.1.stable/`.

```bash
tools/build_all.sh macos
# Or select an editor installed elsewhere:
GODOT=/path/to/godot tools/build_all.sh macos
```

This works on Linux and macOS. The Mac-only build does not need Xcode, Apple credentials or the Android SDK. It needs `shasum` for the checksum; it is included with macOS and provided by Perl's Digest::SHA tooling on Linux.

Outputs:

| Path | Contents |
|---|---|
| `build/macos/PhreakNIC-CCG-v<version>.zip` | Universal `.app`, with executable permissions preserved |
| `build/macos/SHA256SUMS.txt` | SHA-256 checksum of the ZIP |
| `build/release/PhreakNIC-CCG-macos.zip` | Stable release asset name, created by the full release packaging command |

Godot generates the Mac icon from the existing PNG. Bundle versions inherit `project.godot` automatically.

With no arguments, `tools/build_all.sh` now builds Linux, Windows, macOS, Android and web, then packages the native downloads. `tools/build_all.sh release` packages outputs already built for the current version and requires the Mac ZIP as well as the existing Linux/Windows/Android outputs. The Android release-signing guard remains in place. A missing Mac ZIP is rejected before existing release files are removed. A maintainer must publish the Mac asset before adding a download link to the game's web menu.

## Download and install a CI build

Open a successful **Apple builds** Actions run. Download either `macos-macos-15` or `macos-macos-15-intel`: both contain the same universal app, rather than separate CPU-specific products. GitHub may require sign-in. CI artifacts are retained for seven days.

1. Extract the downloaded Actions artifact archive.
2. Extract `PhreakNIC-CCG-v<version>.zip` inside it.
3. Move the `.app` to Applications and open it.

The preset uses **Testing**, **Built-in (ad-hoc only)** signing, disabled notarization and no App Sandbox. It is a direct-download preview, not a Mac App Store build. Ad-hoc signing supplies the signature needed on Apple Silicon but does not establish an Apple-verified publisher.

A downloaded copy may be blocked by Gatekeeper. After verifying its source, use Apple's **System Settings → Privacy & Security → Open Anyway** process if offered. See [Apple's instructions](https://support.apple.com/en-us/102445). Saves normally live in `~/Library/Application Support/Godot/app_userdata/PhreakNIC CCG/`; browser saves are not automatically migrated.

## Developer ID signing and notarization

For a notarized public download, configure an Apple Developer ID certificate and notarization separately. Godot supports this from Linux with `rcodesign`. Select **Distribution**, **rcodesign** signing and **rcodesign** notarization in the Mac export options; set the executable path in Godot's editor settings and the appropriate Apple Team ID. Keep the debugging entitlement disabled.

Keep certificates, passwords and App Store Connect private keys outside the repository. Godot accepts credential environment variables:

```text
GODOT_MACOS_CODESIGN_CERTIFICATE_FILE
GODOT_MACOS_CODESIGN_CERTIFICATE_PASSWORD
GODOT_MACOS_NOTARIZATION_API_UUID
GODOT_MACOS_NOTARIZATION_API_KEY
GODOT_MACOS_NOTARIZATION_API_KEY_ID
```

Follow [Godot's signing and notarization instructions](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html), including checking acceptance and stapling the ticket. Repackage and regenerate checksums after modifying/signing the app. The default preview export needs no Apple credentials.

## Validation and remaining checks

The Apple workflow builds on Intel and Apple Silicon Mac runners, verifies the bundle with `codesign --verify --deep --strict`, launches the packaged executable headlessly, and runs `v07_checks` and `v08_checks`. Downloads of the editor/templates are checked against pinned SHA-256 hashes. The initial [v0.29 fork run](https://github.com/bitwize-music/PhreakNIC-CCG/actions/runs/43761358237) passed these checks, and a tester subsequently reported that the downloaded app runs on their Mac. That report does not specify the CPU/OS or establish complete gameplay coverage.

Manual checks still needed before treating the port as fully tested:

- Minimum supported OS versions on both architectures; Retina rendering, resizing and fullscreen.
- Tutorial/offline play; card previews and trackpad scrolling; music and sound.
- Save, quit, relaunch/resume and Command-Q during a game.
- Deck/result-image exports, clipboard/browser links and macOS bug-report selection.
- Online play against another platform on the same version; disconnect/reconnect and sleep/wake.
- For a notarized release, a fresh browser download and Gatekeeper behavior without developer overrides.

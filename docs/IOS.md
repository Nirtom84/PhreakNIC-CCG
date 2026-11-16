# Unsigned iOS preview builds

Linux can export the Xcode project. Compiling the ARM64 device executable and packaging the IPA requires macOS and Xcode, including the standard GitHub macOS runners used by the **Apple builds** workflow. No Apple credentials are used by this preview workflow.

## Commands and prerequisites

```bash
tools/build_all.sh ios-project    # Linux or macOS: export the Xcode project
tools/build_all.sh ios           # macOS + Xcode: compile an unsigned device IPA
tools/build_all.sh ios-simulator # macOS + Xcode: compile the Simulator app
```

Install Godot 4.7.1 and its matching standard `ios.zip` export template. The template directory is `~/.local/share/godot/export_templates/4.7.1.stable/` on Linux and `~/Library/Application Support/Godot/export_templates/4.7.1.stable/` on macOS. Set `GODOT=/path/to/Godot` to select another editor location.

Use Xcode 26.3 for the official Godot 4.7.1 template. Its device library references SDK symbols absent from the runner's default Xcode 16.4, so CI explicitly sets `DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer`.

The official 4.7.1 Simulator static library contains x86_64 objects only, despite its XCFramework manifest listing arm64 too. The Simulator command therefore sets `ARCHS=x86_64`, and the iOS CI job uses an Intel Mac (`macos-15-intel`). The device IPA remains ARM64. Use an Intel Mac for this Simulator smoke check.

## Outputs and signing

| Target | Output |
|---|---|
| `ios-project` | `build/ios/project/PhreakNICCCG.xcodeproj`, its resource pack and supporting files |
| `ios` | `build/ios/PhreakNIC-CCG-v<version>-unsigned.ipa` and `build/ios/SHA256SUMS.txt` |
| `ios-simulator` | `build/ios/simulator/Build/Products/Release-iphonesimulator/PhreakNICCCG.app` |

The iOS targets are opt-in. They are not part of the default five-platform build or normal release packaging. The preset targets iPhone/iPad on iOS 15+, uses the shared landscape phone layout, and inherits the game version. Its all-zero Team ID is an explicit placeholder for unsigned project generation, not an Apple signing identity.

An **unsigned IPA cannot be installed directly on an ordinary iPhone**. Sign and provision it using an appropriate Apple identity/device installation tool, or configure a real developer team in Xcode and use its device/TestFlight distribution workflow. The Simulator app receives only an ad-hoc local signature. This workflow does not publish to TestFlight or the App Store, and does not establish App Store readiness. See [Godot's iOS export instructions](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html) for signing setup.

## GitHub Actions builds and downloads

`.github/workflows/apple-builds.yml` supports manual dispatch, relevant pull requests, and relevant pushes to `main` or `build/apple-*` branches. Standard GitHub-hosted runners are [free for public repositories](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job). The workflow:

- Verifies pinned SHA-256 hashes of the official Godot editor and export templates.
- Builds and tests the universal Mac app on Intel and Apple Silicon runners.
- Compiles the unsigned ARM64 iPhoneOS IPA with code signing disabled.
- Builds/ad-hoc signs the x86_64 Simulator app, installs it, waits for the actual launched app PID, checks that process remains alive and captures a screenshot.
- Uses strict Bash pipeline handling so logging cannot mask build failures.
- Uploads preview artifacts and logs for seven days; it uses no signing secrets or write-enabled checkout credentials.

On a successful run, download `ios-unsigned-preview` from its **Artifacts** section and extract the Actions archive to find the IPA, checksum, build logs, launch PID record and screenshot. GitHub may require sign-in. From Linux, substitute the run's numeric ID:

```bash
gh run download RUN_ID --repo OWNER/PhreakNIC-CCG \
  --name ios-unsigned-preview --dir build/apple-ci/ios
```

The Mac artifacts are `macos-macos-15` and `macos-macos-15-intel`; each contains a universal app ZIP. These are CI previews, not published game release assets.

## Validation and limits

The initial [v0.29 fork run](https://github.com/bitwize-music/PhreakNIC-CCG/actions/runs/43761358237) passed Mac builds/checks on both architectures, compiled the unsigned device IPA and installed/launched the Simulator app. The downloaded IPA passed its checksum check. The inspected Simulator screenshot shows the game's launch splash: **iOS menu rendering and gameplay have not been verified**.

Manual device testing is still needed for menu/gameplay, touch interaction, safe-area layout, native sharing/file export, audio and background/reconnect behavior. The Simulator process check and screenshot are limited startup evidence. In particular, the current safe-area adjustment is Android-specific and file export uses desktop-style destinations, so this work is a build preview rather than a completed iOS UX port.

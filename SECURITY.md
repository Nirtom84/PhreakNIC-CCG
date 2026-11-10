# Security policy

PhreakNIC CCG is made for a hacker conference, so we expect people to poke at it. Thank you for doing it responsibly.

## Reporting a vulnerability

**Please don't open a public issue for security problems.** Report them privately through GitHub:
**Security → Report a vulnerability** on this repository (https://github.com/Nirtom84/PhreakNIC-CCG/security/advisories/new).

Include what you found, how to reproduce it, and what an attacker could do with it. We'll reply as soon as we can, fix it, and credit you in the release notes unless you'd rather stay anonymous.

## In scope

- The online server at `online-01.phreaknic-ccg.net` (rooms, lobby, game protocol, admin panel).
- The website at `phreaknic-ccg.net`.
- The game clients (Windows, Linux, Android, web): cheating online (seeing hidden cards, predicting shuffles, acting for other players), crashing other players or the server, injecting content into other players' screens.
- Release downloads and the build/deploy tooling in this repository.

## Please don't

- Run denial-of-service or load tests against the live servers, or anything that runs up hosting costs.
- Access or change other players' games beyond what's needed to show the problem.
- Social-engineer the maintainers or attack Cloudflare/GitHub themselves.

Testing against your own local server is always fine: `godot --headless -- --server --port 8080` (see `cloudflare/online/README.md`).

## Verifying downloads

Each release has a `SHA256SUMS.txt`. Check a download with `sha256sum -c SHA256SUMS.txt --ignore-missing`.

From v0.11, the Android APK is signed with the project's release key. Its certificate SHA-256 fingerprint is:

```
ae6e0c36327cdeaa54198832d0169543e9b6f9ec87ce560817026b43d9025c95
```

Check it with `apksigner verify --print-certs PhreakNIC-CCG-android.apk`. An APK with a different certificate is not ours.

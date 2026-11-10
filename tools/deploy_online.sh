#!/usr/bin/env bash
set -euo pipefail
DOCKER_CONFIG="$(mktemp -d)"
trap 'rm -rf -- "$DOCKER_CONFIG"' EXIT
export DOCKER_CONFIG
chmod 700 "$DOCKER_CONFIG"
# Docker must be running: Wrangler builds/pushes the amd64 image and uses Docker in dev.
mode="${1:-}"
if [[ $# -gt 1 || ( -n "$mode" && "$mode" != "--dev" ) ]]; then
	printf 'Usage: %s [--dev]\n' "$0" >&2
	exit 2
fi
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Wrangler is pinned in cloudflare/package-lock.json (exact version + integrity hashes).
(cd -- "$repo_root/cloudflare" && npm ci --no-audit --no-fund --silent)
wrangler="$repo_root/cloudflare/node_modules/.bin/wrangler"
game_version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$repo_root/project.godot")"
if [[ -z "$game_version" ]]; then
	printf 'Missing config/version in project.godot.\n' >&2
	exit 1
fi
if [[ ! -f "$repo_root/build/server/phreaknic-server.x86_64" ]]; then
	printf 'Missing server binary. Run tools/build_all.sh server first.\n' >&2
	exit 1
fi
if [[ -z "${CLOUDFLARE_API_TOKEN:-}" && "$mode" != "--dev" ]]; then
	# Runtime only; never print credentials or enable shell tracing here.
	source "$HOME/.config/phreaknic/cf-env.sh"
fi
cp -- "$repo_root/build/server/phreaknic-server.x86_64" "$repo_root/cloudflare/online/container/phreaknic-server.x86_64"
cd -- "$repo_root/cloudflare/online"
if [[ "$mode" == "--dev" ]]; then
	"$wrangler" dev --env dev --var "GAME_VERSION:$game_version"
else
	"$wrangler" deploy --var "GAME_VERSION:$game_version"
fi

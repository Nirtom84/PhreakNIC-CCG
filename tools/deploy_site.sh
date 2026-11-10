#!/usr/bin/env bash
# Publishes the web build (build/web/) to https://phreaknic-ccg.net on Cloudflare.
# - index.wasm (over the 25 MiB static-asset limit) goes to the R2 bucket phreaknic-ccg-files
#   under web/<version>/index.wasm; the site Worker streams it from there.
# - Every other file is uploaded as a Workers static asset.
# Needs CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID in the environment, or a private loader at
# ~/.config/phreaknic/cf-env.sh that exports them (never in this repo). Usage: tools/build_all.sh web && tools/deploy_site.sh
set -euo pipefail
DOCKER_CONFIG="$(mktemp -d)"
trap 'rm -rf -- "$DOCKER_CONFIG"' EXIT
export DOCKER_CONFIG
chmod 700 "$DOCKER_CONFIG"
cd "$(dirname "$0")/.."

VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
[ -f build/web/index.html ] && [ -f build/web/index.wasm ] || { echo "No web build: run tools/build_all.sh web first" >&2; exit 1; }
# Credentials come from the environment, or from a private loader script outside the repo
# (~/.config/phreaknic/cf-env.sh) that exports CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID.
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && [ -f "$HOME/.config/phreaknic/cf-env.sh" ]; then
	. "$HOME/.config/phreaknic/cf-env.sh"
fi
[ -n "${CLOUDFLARE_API_TOKEN:-}" ] || { echo "Set CLOUDFLARE_API_TOKEN (and CLOUDFLARE_ACCOUNT_ID), or provide ~/.config/phreaknic/cf-env.sh" >&2; exit 1; }

# Wrangler is pinned in cloudflare/package-lock.json (exact version + integrity hashes).
(cd cloudflare && npm ci --no-audit --no-fund --silent)
WRANGLER="$PWD/cloudflare/node_modules/.bin/wrangler"
BUCKET="phreaknic-ccg-files"
KEY="web/$VERSION/index.wasm"

# Keep the big engine file out of the static assets.
printf 'index.wasm\n.assetsignore\n' > build/web/.assetsignore
# Expand the path now: the script changes directory before it exits.
assetsignore_path="$PWD/build/web/.assetsignore"
trap 'rm -f -- "$assetsignore_path"; rm -rf -- "$DOCKER_CONFIG"' EXIT

cd cloudflare/site
"$WRANGLER" r2 bucket create "$BUCKET" 2>/dev/null || true   # no-op if it already exists
"$WRANGLER" r2 object put "$BUCKET/$KEY" --file ../../build/web/index.wasm --content-type application/wasm --remote
"$WRANGLER" deploy --var "WASM_KEY:$KEY"
echo "Deployed v$VERSION to https://phreaknic-ccg.net"

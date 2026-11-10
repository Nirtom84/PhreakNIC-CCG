#!/usr/bin/env bash
# Publishes the web build (build/web/) to https://phreaknic-ccg.net on Cloudflare.
# - index.wasm (over the 25 MiB static-asset limit) goes to the R2 bucket phreaknic-ccg-files
#   under web/<version>/index.wasm; the site Worker streams it from there.
# - Every other file is uploaded as a Workers static asset.
# Needs a Cloudflare API token in CLOUDFLARE_API_TOKEN, or in ~/.config/phreaknic/cloudflare.env
# (never in this repo). Usage: tools/build_all.sh web && tools/deploy_site.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
[ -f build/web/index.html ] && [ -f build/web/index.wasm ] || { echo "No web build: run tools/build_all.sh web first" >&2; exit 1; }
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && [ -f "$HOME/.config/phreaknic/cloudflare.env" ]; then
	set -a; . "$HOME/.config/phreaknic/cloudflare.env"; set +a
fi
[ -n "${CLOUDFLARE_API_TOKEN:-}" ] || { echo "Set CLOUDFLARE_API_TOKEN or create ~/.config/phreaknic/cloudflare.env" >&2; exit 1; }

WRANGLER="npx --yes wrangler@4"
BUCKET="phreaknic-ccg-files"
KEY="web/$VERSION/index.wasm"

# Keep the big engine file out of the static assets.
printf 'index.wasm\n.assetsignore\n' > build/web/.assetsignore

cd cloudflare/site
$WRANGLER r2 bucket create "$BUCKET" 2>/dev/null || true   # no-op if it already exists
$WRANGLER r2 object put "$BUCKET/$KEY" --file ../../build/web/index.wasm --content-type application/wasm --remote
$WRANGLER deploy --var "WASM_KEY:$KEY"
echo "Deployed v$VERSION to https://phreaknic-ccg.net"

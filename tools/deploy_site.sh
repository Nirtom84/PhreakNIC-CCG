#!/usr/bin/env bash
# Publishes the web build (build/web/) to https://phreaknic-ccg.net on Cloudflare.
# - index.wasm and index.pck (over the 25 MiB static-asset limit) go to the R2 bucket phreaknic-ccg-files
#   under web/<version>/; the site Worker streams them from there.
# - Every other file is uploaded as a Workers static asset.
# Needs CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID in the environment, or a private loader at
# ~/.config/phreaknic/cf-env.sh that exports them (never in this repo). Usage: tools/build_all.sh web && tools/deploy_site.sh
set -euo pipefail
DOCKER_CONFIG="$(mktemp -d)"
trap 'rm -rf -- "$DOCKER_CONFIG"' EXIT
export DOCKER_CONFIG
chmod 700 "$DOCKER_CONFIG"
cd "$(dirname "$0")/.."
check_root="$PWD"
dirty_status="$(git -C "$check_root" status --porcelain --untracked-files=no)"
if [[ -n "$dirty_status" ]]; then
 if [[ "${FORCE_DIRTY:-}" != 1 ]]; then echo "Tracked files have uncommitted changes; refusing deploy (FORCE_DIRTY=1 overrides)." >&2; exit 1; fi
 echo "WARNING: FORCE_DIRTY=1: deploying with tracked changes." >&2
fi
build_commit="$(head -n 1 "$check_root/build/web/BUILD_COMMIT")"
if [[ "$(sed -n '2p' "$check_root/build/web/BUILD_COMMIT")" == dirty && "${FORCE_DIRTY:-}" != 1 ]]; then
 echo "Build was made from tracked changes; refusing dirty build (FORCE_DIRTY=1 overrides)." >&2; exit 1
fi
[[ "$build_commit" == "$(git -C "$check_root" rev-parse HEAD)" ]] || { echo "Build commit differs from HEAD; rebuild first." >&2; exit 1; }


VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
[ -f build/web/index.html ] && [ -f build/web/index.wasm ] || { echo "No web build: run tools/build_all.sh web first" >&2; exit 1; }
# Wrangler is pinned in cloudflare/package-lock.json (exact version + integrity hashes).
(cd cloudflare && npm ci --no-audit --no-fund --silent)
WRANGLER="$PWD/cloudflare/node_modules/.bin/wrangler"
# Credentials come from the environment, or from a private loader script outside the repo
# (~/.config/phreaknic/cf-env.sh) that exports CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID.
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && [ -f "$HOME/.config/phreaknic/cf-env.sh" ]; then
	. "$HOME/.config/phreaknic/cf-env.sh"
fi
[ -n "${CLOUDFLARE_API_TOKEN:-}" ] || { echo "Set CLOUDFLARE_API_TOKEN (and CLOUDFLARE_ACCOUNT_ID), or provide ~/.config/phreaknic/cf-env.sh" >&2; exit 1; }


BUCKET="phreaknic-ccg-files"
KEY="web/$VERSION/index.wasm"
PCK_KEY="web/$VERSION/index.pck"

# Keep the big engine and data files out of the static assets.
# music/*.ogg stays in static assets (same-origin lazy soundtrack downloads).
printf 'index.wasm\nindex.pck\n.assetsignore\n' > build/web/.assetsignore
# Expand the path now: the script changes directory before it exits.
assetsignore_path="$PWD/build/web/.assetsignore"
trap 'rm -f -- "$assetsignore_path"; rm -rf -- "$DOCKER_CONFIG"' EXIT

cd cloudflare/site
"$WRANGLER" r2 bucket create "$BUCKET" 2>/dev/null || true   # no-op if it already exists
# Verify both immutable assets before uploading either one. A failed lookup is
# accepted only for an explicit missing-object response; auth/network errors stop.
for asset in index.pck index.wasm; do
 remote_file="$DOCKER_CONFIG/$asset"
 lookup_log="$DOCKER_CONFIG/lookup.log"
 if "$WRANGLER" r2 object get "$BUCKET/web/$VERSION/$asset" --file "$remote_file" --remote >"$lookup_log" 2>&1; then
  if ! cmp -s "$remote_file" "../../build/web/$asset"; then
   echo "Version $VERSION already has different $asset bytes. Bump the project version before deploying." >&2
   exit 1
  fi
 elif ! grep -Eq 'NoSuchKey|The specified key does not exist' "$lookup_log"; then
  echo "Cannot verify remote version $VERSION; refusing to upload. Check R2 access and retry." >&2
  exit 1
 fi
done
"$WRANGLER" r2 object put "$BUCKET/$KEY" --file ../../build/web/index.wasm --content-type application/wasm --remote
"$WRANGLER" r2 object put "$BUCKET/$PCK_KEY" --file ../../build/web/index.pck --content-type application/octet-stream --remote
"$WRANGLER" deploy --var "WASM_KEY:$KEY" --var "PCK_KEY:$PCK_KEY"
echo "Deployed v$VERSION to https://phreaknic-ccg.net"

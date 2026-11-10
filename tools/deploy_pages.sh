#!/usr/bin/env bash
# Publishes the web build (build/web/) to GitHub Pages by replacing the gh-pages branch.
# The branch holds only the latest build, so large web builds don't pile up in history.
# Usage: tools/build_all.sh web && tools/deploy_pages.sh
set -euo pipefail
cd "$(dirname "$0")/.."
repo_dir="$(pwd)"

VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
[ -f build/web/index.html ] || { echo "No web build found: run tools/build_all.sh web first" >&2; exit 1; }
remote="$(git remote get-url origin)"

site="$(mktemp -d)"
trap 'rm -rf "$site"' EXIT
cp -r build/web/. "$site/"
touch "$site/.nojekyll"   # serve files as-is, no Jekyll processing

cd "$site"
git init -q -b gh-pages
git add -A
git -c user.name="$(git -C "$repo_dir" config user.name)" -c user.email="$(git -C "$repo_dir" config user.email)" \
	commit -q -m "Web build v$VERSION"
git push -q -f "$remote" gh-pages
echo "Deployed v$VERSION to the gh-pages branch."

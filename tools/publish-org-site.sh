#!/usr/bin/env bash
#
# Publish the Indirimbo Zikundwa landing site to its own GitHub subdomain:
#   https://indirimbo-zikundwa.github.io/
#
# PREREQUISITE (one-time, you must do this in the browser — GitHub has no API
# to create a free organisation):
#
#   1. Go to  https://github.com/account/organizations/new?plan=free
#   2. Organisation name:  indirimbo-zikundwa
#   3. Finish the free plan signup.
#
# Then just run this script. It creates the  indirimbo-zikundwa.github.io  repo
# under that org, copies the website (rewriting absolute URLs to the new domain),
# pushes it, and enables GitHub Pages. Re-running it simply updates the site.
#
set -euo pipefail

ORG="indirimbo-zikundwa"
REPO="$ORG/$ORG.github.io"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/website"
OLD_URL="reneuwumuhire.github.io/indirimbo-zikundwa"
NEW_URL="indirimbo-zikundwa.github.io"

echo "▶ Checking that the '$ORG' organisation exists…"
if ! gh api "orgs/$ORG" >/dev/null 2>&1; then
  cat >&2 <<EOF

✗ The organisation '$ORG' doesn't exist yet.

  Create it (free, ~1 min) here, then re-run this script:
    https://github.com/account/organizations/new?plan=free
  Organisation account name:  $ORG

EOF
  exit 1
fi

echo "▶ Ensuring the repo $REPO exists…"
if ! gh repo view "$REPO" >/dev/null 2>&1; then
  gh repo create "$REPO" --public \
    --description "Indirimbo Zikundwa — 5,495 hymns, fully offline. Official site."
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "▶ Preparing site contents…"
git clone --quiet "https://github.com/$REPO.git" "$TMP/site" 2>/dev/null || {
  mkdir -p "$TMP/site" && cd "$TMP/site" && git init -q && \
  git remote add origin "https://github.com/$REPO.git"
}
cd "$TMP/site"

# Copy the website to the repo root and point absolute URLs at the new domain.
cp -R "$SRC/." .
for f in index.html privacy.html terms.html sitemap.xml robots.txt README.md; do
  [ -f "$f" ] && sed -i '' "s#$OLD_URL#$NEW_URL#g" "$f" 2>/dev/null \
              || { [ -f "$f" ] && sed -i "s#$OLD_URL#$NEW_URL#g" "$f"; }
done

git add -A
git -c user.name="Rene Uwumuhire" -c user.email="bajustone@gmail.com" \
    commit -q -m "Publish Indirimbo Zikundwa site" || echo "  (no changes to commit)"
git branch -M main
echo "▶ Pushing to $REPO…"
git push -u origin main --force

echo "▶ Enabling GitHub Pages…"
gh api -X POST "repos/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || gh api -X PUT "repos/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || true

echo ""
echo "✓ Done. Your site will be live shortly at:  https://$NEW_URL/"
echo "  (first build can take 1–2 minutes)"

#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Creates a GitHub release for the signed Vanadium-E APKs. Run it on the machine that built them.
#
#   E/tools/publish-release.sh               create a DRAFT release (review it on GitHub, then publish there)
#   E/tools/publish-release.sh --publish     create it already public
#   E/tools/publish-release.sh --dry-run     check everything and show what would happen, change nothing
#   E/tools/publish-release.sh --tag TAG     use this tag instead of <chromium version>-e<N>
#
# Needs the GitHub CLI (`sudo apt install gh`, then `gh auth login`), a clean checkout whose HEAD is
# pushed, and the signed APKs from `build-ubuntu.sh sign`. Environment (optional):
#   WORK=~/vanadium-e-build   APK_DIR=<dir with the signed APKs>   REPO=owner/name
#   APKSIGNER=<path to apksigner>   VANADIUM_E_CERT_DIGEST=<digest, if not set in E/args.gn.overlay>
set -o errexit -o nounset -o pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
WORK=${WORK:-$HOME/vanadium-e-build}
APK_DIR=${APK_DIR:-$WORK/chromium/src/out/Default/apks/release}
APKSIGNER=${APKSIGNER:-$WORK/chromium/src/third_party/android_sdk/public/build-tools/37.0.0/apksigner}
publish=0; dry=0; tag=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --publish) publish=1 ;; --dry-run) dry=1 ;; --tag) tag=${2:?--tag needs a value}; shift ;;
        -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1"; exit 2 ;;
    esac; shift
done
die() { echo "error: $*" >&2; exit 1; }
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

command -v gh >/dev/null || die "GitHub CLI not found. Install it (sudo apt install gh) and run: gh auth login"
gh auth status >/dev/null 2>&1 || die "not logged in to GitHub. Run: gh auth login"

# --- repository and source state
if [[ -z ${REPO:-} ]]; then
    url=$(git remote get-url origin)
    REPO=$(sed -E 's#^(https://|git@)github\.com[:/]##; s#\.git$##' <<< "$url")
fi
[[ $REPO =~ ^[^/]+/[^/]+$ ]] || die "could not determine owner/name from origin; set REPO=owner/name"
[[ -z $(git status --porcelain) ]] || die "working tree has uncommitted changes; commit or stash them first"
git fetch -q origin
commit=$(git rev-parse HEAD)
git branch -r --contains "$commit" | grep -q 'origin/' || die "HEAD ($commit) is not pushed. Push it so the release points at public source."

# --- version and tag
version=$(sed -n 's/^android_default_version_name = "\(.*\)"/\1/p' args.gn)
[[ -n $version ]] || die "could not read Chromium version from args.gn"
if [[ -z $tag ]]; then
    last=$(gh release list --repo "$REPO" --limit 200 --json tagName --jq '.[].tagName' \
        | sed -n "s/^${version//./\\.}-e\([0-9][0-9]*\)$/\1/p" | sort -n | tail -1)
    tag="$version-e$(( ${last:-0} + 1 ))"
fi
gh release view "$tag" --repo "$REPO" >/dev/null 2>&1 && die "release $tag already exists"

# --- the APKs, and proof they carry the right signing key
apks=(TrichromeLibrary.apk TrichromeChrome.apk VanadiumConfig.apk)
for a in "${apks[@]}"; do [[ -s $APK_DIR/$a ]] || die "missing $APK_DIR/$a (run: E/tools/build-ubuntu.sh sign)"; done
digest=$(sed -n 's/^trichrome_certdigest = "\([0-9a-f]\{64\}\)"/\1/p' E/args.gn.overlay)
digest=${digest:-${VANADIUM_E_CERT_DIGEST:-}}
[[ $digest =~ ^[0-9a-f]{64}$ ]] || die "no signing cert digest (set VANADIUM_E_CERT_DIGEST)"
[[ -x $APKSIGNER ]] || die "apksigner not found at $APKSIGNER (set APKSIGNER)"
for a in "${apks[@]}"; do
    got=$("$APKSIGNER" verify --print-certs "$APK_DIR/$a" 2>&1 | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -1)
    [[ $got == "$digest" ]] || die "$a is not signed with the Vanadium-E key (cert digest '${got:-none}', expected $digest)"
    echo "verified signature: $a"
done

# --- release assets and notes
stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
for a in "${apks[@]}"; do cp "$APK_DIR/$a" "$stage/"; done
( cd "$stage" && sha256 "${apks[@]}" > SHA256SUMS )
cat > "$stage/notes.md" <<NOTES
Unofficial Vanadium-E build on Chromium \`$version\`. Not affiliated with or endorsed by GrapheneOS.

**Install in this order:** \`TrichromeLibrary.apk\`, \`TrichromeChrome.apk\`, \`VanadiumConfig.apk\`.
Vanadium-E uses its own signing key: it installs alongside Vanadium and updates earlier Vanadium-E builds, but cannot replace Vanadium.

**Signing certificate SHA-256:** \`$digest\`

**Checksums (SHA-256):**
\`\`\`
$(cat "$stage/SHA256SUMS")
\`\`\`

**Source (GPL-2.0-only):** https://github.com/$REPO/tree/$commit (Vanadium patches in \`patches/\`, Vanadium-E patches in \`E/\`). Chromium source: tag \`$version\` at https://chromium.googlesource.com/chromium/src/+/refs/tags/$version
NOTES

echo
echo "repo:    $REPO"
echo "tag:     $tag   (commit ${commit:0:12})"
echo "mode:    $([[ $publish == 1 ]] && echo PUBLIC || echo draft)"
echo "assets:  ${apks[*]} SHA256SUMS"
if (( dry )); then echo; echo "dry run: nothing created"; exit 0; fi

flags=(--draft); (( publish )) && flags=()
gh release create "$tag" "$stage"/*.apk "$stage/SHA256SUMS" --repo "$REPO" --target "$commit" \
    --title "Vanadium-E $tag" --notes-file "$stage/notes.md" "${flags[@]}"
echo "done. $([[ $publish == 1 ]] || echo "Review the draft at https://github.com/$REPO/releases and press Publish.")"

#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Lightweight check that the Vanadium-E patches still apply on top of Vanadium's patches, WITHOUT
# a full Chromium checkout: downloads only the few Chromium files the E patches touch, at the
# version in args.gn, applies Vanadium's patches (limited to those files), then the E patches.
# Catches conflicts early; a real build is still the final test. Needs git, curl, python3.
set -o errexit -o nounset -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
version=$(sed -n 's/^android_default_version_name = "\(.*\)"/\1/p' "$root/args.gn")
base=https://chromium.googlesource.com
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
fetch() { # fetch <url> <dest>; 0 = ok, 1 = HTTP 404 (file absent), exits on persistent network errors
    mkdir -p "$(dirname "$2")"
    local code i
    for i in 1 2 3 4; do
        code=$(curl -sL -m 120 -o "$2.b64" -w '%{http_code}' "$1?format=TEXT" || true)
        if [[ $code == 200 ]]; then base64 -d < "$2.b64" > "$2"; rm -f "$2.b64"; return 0; fi
        rm -f "$2.b64"
        [[ $code == 404 ]] && return 1
        sleep $((i * 3))
    done
    echo "network error (HTTP $code) fetching $1"; exit 2
}
git_init() { git -C "$1" init -q; git -C "$1" config user.email check@example.invalid; git -C "$1" config user.name check; }
fail=0

echo "== Chromium $version: E patches on top of Vanadium patches"
src=$work/src; mkdir -p "$src"; git_init "$src"
files=$(cat "$root"/E/patches/E-*.patch | sed -n 's|^diff --git a/\([^ ]*\) .*|\1|p' | sort -u)
while IFS= read -r f; do
    # Files created by Vanadium's patches (404 upstream) are simply absent until those apply.
    fetch "$base/chromium/src/+/refs/tags/$version/$f" "$src/$f" || rm -f "$src/$f"
done <<< "$files"
for p in "$root"/patches/*.patch; do
    inc=()
    while IFS= read -r f; do
        grep -q "^diff --git a/$f " "$p" && inc+=("--include=$f")
    done <<< "$files"
    [[ ${#inc[@]} -gt 0 ]] || continue
    git -C "$src" apply "${inc[@]}" --recount "$p" 2>"$work/err" || { echo "FAIL: Vanadium patch $(basename "$p") on tracked files"; sed 's/^/    /' "$work/err" | head -5; fail=1; }
done
git -C "$src" add -A; git -C "$src" commit -qm base
for p in "$root"/E/patches/E-*.patch; do
    if git -C "$src" am -q --whitespace=nowarn --keep-non-patch "$p" 2>"$work/err"; then echo "ok   $(basename "$p")"
    else echo "FAIL $(basename "$p")"; sed 's/^/    /' "$work/err" | head -5; git -C "$src" am --abort 2>/dev/null || true; fail=1; fi
done

echo "== search_engines_data submodule patches"
deps=$(curl -sfL --retry 3 "$base/chromium/src/+/refs/tags/$version/DEPS?format=TEXT" | base64 -d)
pin=$(grep -A1 "'src/third_party/search_engines_data/resources':" <<< "$deps" | grep -o '[0-9a-f]\{40\}' | head -1)
if [[ -z $pin ]]; then echo "FAIL: could not find search_engines_data pin in DEPS"; fail=1; else
    sub=$work/sub; mkdir -p "$sub"; git_init "$sub"
    for f in definitions/prepopulated_engines.json definitions/regional_settings.json; do
        fetch "$base/external/search_engines_data/+/$pin/$f" "$sub/$f" || { echo "FAIL: fetch $f"; fail=1; }
    done
    git -C "$sub" add -A; git -C "$sub" commit -qm base
    for p in "$root"/subprojects_patches/third_party/search_engines_data/resources/*.patch \
             "$root"/E/subprojects_patches/third_party/search_engines_data/resources/E-*.patch; do
        if git -C "$sub" am -q --whitespace=nowarn "$p" 2>"$work/err"; then echo "ok   $(basename "$p")"
        else echo "FAIL $(basename "$p")"; sed 's/^/    /' "$work/err" | head -5; git -C "$sub" am --abort 2>/dev/null || true; fail=1; fi
    done
fi

if (( fail )); then echo; echo "RESULT: FAIL - some patches need to be rebased"; exit 1; fi
echo; echo "RESULT: PASS"

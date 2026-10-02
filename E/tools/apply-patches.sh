#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Phase 1. Run inside the Chromium checkout's src/ at the version tag, BEFORE `gclient sync`:
#   /path/to/Vanadium-E/E/tools/apply-patches.sh
# Applies unmodified Vanadium patches, then Vanadium-E patches, then rebrands in-app strings.
set -o errexit -o nounset -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
src=$PWD

git am --whitespace=nowarn --keep-non-patch "$root"/patches/*.patch

shopt -s nullglob
e=("$root"/E/patches/E-*.patch)
[[ ${#e[@]} -gt 0 ]] && git am --whitespace=nowarn --keep-non-patch "${e[@]}"

# Rebrand visible in-app strings to Vanadium-E (script, so upstream string changes never conflict).
python3 "$root/E/tools/rebrand-strings.py" "$src"
git add -A -- '*.grd' '*.grdp'
git commit -q -m "E: rebrand in-app strings to Vanadium-E" || true

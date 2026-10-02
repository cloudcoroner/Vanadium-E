#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Usage (from a Chromium checkout at the tag Vanadium targets, after `gclient sync`):
#   /path/to/Vanadium-E/E/tools/apply-patches.sh
# Applies unmodified Vanadium patches first, then Vanadium-E patches in order,
# including the patches for the search_engines_data submodule.
set -o errexit -o nounset -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
src=$PWD

git am --3way "$root"/patches/*.patch
python3 "$root/tools/common/apply_subprojects_patches.py" --src_dir "$src" --base_patch_dir "$root/subprojects_patches"

shopt -s nullglob
e=("$root"/E/patches/E-*.patch)
[[ ${#e[@]} -gt 0 ]] && git am --3way "${e[@]}"

# Rebrand visible in-app strings to Vanadium-E (done by script so upstream string changes never conflict).
python3 "$root/E/tools/rebrand-strings.py" "$src"
git add -A -- '*.grd' '*.grdp'
git commit -q -m "E: rebrand in-app strings to Vanadium-E" || true

# Vanadium-E submodule patches, e.g. E/subprojects_patches/<subproject path>/E-*.patch
for d in "$root"/E/subprojects_patches/third_party/search_engines_data/resources; do
    sub=${d#"$root"/E/subprojects_patches/}
    for p in "$d"/E-*.patch; do
        git -C "$src/$sub" am --whitespace=nowarn "$p"
    done
done

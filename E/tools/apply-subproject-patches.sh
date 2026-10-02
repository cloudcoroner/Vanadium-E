#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Phase 2. Run inside src/ AFTER `gclient sync` (which fetches the subprojects), and do not run
# `gclient sync` again afterwards, since it would reset the subprojects. Safe to re-run.
set -o errexit -o nounset -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
src=$PWD

# Vanadium's own subproject patches (v8, search_engines_data); skips ones already applied.
python3 "$root/tools/common/apply_subprojects_patches.py" --src_dir "$src" --base_patch_dir "$root/subprojects_patches"

# Vanadium-E subproject patches: E/subprojects_patches/<subproject path>/E-*.patch
shopt -s nullglob globstar
for p in "$root"/E/subprojects_patches/**/E-*.patch; do
    sub=$(dirname "${p#"$root"/E/subprojects_patches/}")
    # A patch that reverses cleanly is already applied.
    if git -C "$src/$sub" apply --check --reverse "$p" 2>/dev/null; then
        echo "already applied: $(basename "$p")"
    else
        git -C "$src/$sub" am --whitespace=nowarn "$p"
    fi
done

#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Usage (from a Chromium checkout at the tag Vanadium targets): /path/to/Vanadium-E/E/tools/apply-patches.sh
# Applies unmodified Vanadium patches first, then Vanadium-E patches in order.
set -o errexit -o nounset -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
git am --3way "$root"/patches/*.patch
shopt -s nullglob
e=("$root"/E/patches/*.patch)
[[ ${#e[@]} -gt 0 ]] && git am --3way "${e[@]}"
python3 "$root/tools/common/apply_subprojects_patches.py" "$root/subprojects_patches" 2>/dev/null || true

#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Usage: E/tools/build-args.sh > out/Default/args.gn
# Emits Vanadium's args.gn with keys from E/args.gn.overlay replacing the originals.
set -o errexit -o nounset -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
overlay=$root/E/args.gn.overlay
keys=$(sed -n 's/^\([a-z_0-9]*\) *=.*/\1/p' "$overlay" | paste -sd'|' -)
grep -vE "^($keys) *=" "$root/args.gn"
echo
echo "# --- Vanadium-E overrides ---"
grep -v '^#' "$overlay" | sed '/^$/d'

#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Usage: E/tools/build-args.sh > out/Default/args.gn
# Emits Vanadium's args.gn with keys from E/args.gn.overlay replacing the originals.
# The signing certificate digests (trichrome_certdigest, config_apk_certdigest) come from the
# overlay if it defines them, otherwise from $VANADIUM_E_CERT_DIGEST (64 lowercase hex chars,
# see cert-digest.sh). Vanadium's own digests are never used.
set -o errexit -o nounset -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
overlay=$root/E/args.gn.overlay
keys=$(sed -n 's/^\([a-z_0-9]*\) *=.*/\1/p' "$overlay" | paste -sd'|' -)
digest_keys='trichrome_certdigest|config_apk_certdigest'
grep -vE "^(${keys:+$keys|}$digest_keys) *=" "$root/args.gn"
echo
echo "# --- Vanadium-E overrides ---"
grep -v '^#' "$overlay" | sed '/^$/d'
if ! grep -q '^trichrome_certdigest *=' "$overlay"; then
    d=${VANADIUM_E_CERT_DIGEST:-}
    [[ $d =~ ^[0-9a-f]{64}$ ]] || { echo "set VANADIUM_E_CERT_DIGEST to your signing cert digest (E/tools/cert-digest.sh prints it)" >&2; exit 1; }
    echo "trichrome_certdigest = \"$d\""
    echo "config_apk_certdigest = \"$d\""
fi

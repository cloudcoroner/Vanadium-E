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
# The config app version doubles as the ruleset version the browser indexes. Vanadium-E's list content
# differs from upstream's, so it must be higher than upstream's for every revision of the lists:
# version = upstream * 100 + the number in E/config-revision (bump it whenever the lists change).
version_keys='config_apk_version_name|config_apk_version_code'
grep -vE "^(${keys:+$keys|}$digest_keys|$version_keys) *=" "$root/args.gn"
echo
echo "# --- Vanadium-E overrides ---"
grep -v '^#' "$overlay" | sed '/^$/d'
up=$(sed -n 's/^config_apk_version_code = "\([0-9]*\)"/\1/p' "$root/args.gn")
rev=$(tr -dc '0-9' < "$root/E/config-revision" 2>/dev/null)
[[ -n $up && -n $rev ]] || { echo "cannot compute the config version (upstream '${up}', E/config-revision '${rev}')" >&2; exit 1; }
v=$(( up * 100 + rev ))
echo "config_apk_version_name = \"$v\""
echo "config_apk_version_code = \"$v\""
if ! grep -q '^trichrome_certdigest *=' "$overlay"; then
    d=${VANADIUM_E_CERT_DIGEST:-}
    [[ $d =~ ^[0-9a-f]{64}$ ]] || { echo "set VANADIUM_E_CERT_DIGEST to your signing cert digest (E/tools/cert-digest.sh prints it)" >&2; exit 1; }
    echo "trichrome_certdigest = \"$d\""
    echo "config_apk_certdigest = \"$d\""
fi

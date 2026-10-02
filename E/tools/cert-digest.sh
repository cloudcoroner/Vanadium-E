#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Prints the SHA-256 certificate digest of the Vanadium-E key in the format args.gn expects
# (lowercase hex, no colons). With --write, also fills it into E/args.gn.overlay.
set -o errexit -o nounset -o pipefail
ks=${VANADIUM_E_KEYSTORE:-$HOME/.vanadium-e/vanadium-e.keystore}
root=$(cd "$(dirname "$0")/../.." && pwd)
digest=$(keytool -list -v -keystore "$ks" -alias vanadium-e | sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' | tr -d ':' | tr 'A-F' 'a-f')
[[ ${#digest} -eq 64 ]] || { echo "could not read digest from $ks"; exit 1; }
echo "$digest"
if [[ ${1:-} == --write ]]; then
    sed -i.bak -E "s/^(trichrome_certdigest|config_apk_certdigest) = .*/\1 = \"$digest\"/" "$root/E/args.gn.overlay"
    rm -f "$root/E/args.gn.overlay.bak"
    echo "updated E/args.gn.overlay"
fi

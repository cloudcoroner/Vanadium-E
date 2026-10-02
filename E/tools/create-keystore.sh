#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Creates the Vanadium-E signing key OUTSIDE the repo. You will be prompted for a passphrase
# and certificate details. Back the keystore up: losing it means you can never ship updates
# that install over existing Vanadium-E installs.
set -o errexit -o nounset -o pipefail
ks=${VANADIUM_E_KEYSTORE:-$HOME/.vanadium-e/vanadium-e.keystore}
[[ -e $ks ]] && { echo "$ks already exists, refusing to overwrite"; exit 1; }
mkdir -p "$(dirname "$ks")" && chmod 700 "$(dirname "$ks")"
keytool -genkeypair -v -keystore "$ks" -alias vanadium-e \
    -storetype pkcs12 -keyalg RSA -keysize 4096 -sigalg SHA512withRSA -validity 36500 -dname "CN=Vanadium-E"
chmod 600 "$ks"
echo
echo "Created $ks. Now run: $(dirname "$0")/cert-digest.sh --write"

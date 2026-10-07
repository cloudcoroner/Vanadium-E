#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Builds and signs Vanadium-E on Ubuntu (24.04 LTS recommended, x86_64).
#
#   E/tools/build-ubuntu.sh            run every phase (skips phases already done)
#   E/tools/build-ubuntu.sh <phase>    run one phase: deps | fetch | patch | sync | subpatch | gn | build | sign
#   FORCE=1 ...                        re-run phases even if already done
#   IGNORE_SPECS=1 ...                 skip only the RAM/disk checks (build may be slow or run out of space)
#
# Environment (all optional):
#   WORK=~/vanadium-e-build                       where Chromium is checked out
#   VANADIUM_E_KEYSTORE=~/.vanadium-e/vanadium-e.keystore   signing key (copy it to this machine first)
#   JOBS=$(nproc)                                  parallel jobs for gclient sync
#
# Needs: 32 GiB+ RAM (CFI+LTO link), ~300 GB free disk, and hours of time. Resumable: if a step
# fails (e.g. network), fix the cause and re-run; finished phases are skipped.
set -o errexit -o nounset -o pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
WORK=${WORK:-$HOME/vanadium-e-build}
JOBS=${JOBS:-$(nproc)}
export VANADIUM_E_KEYSTORE=${VANADIUM_E_KEYSTORE:-$HOME/.vanadium-e/vanadium-e.keystore}
export PATH=$HOME/depot_tools:$PATH
export DEPOT_TOOLS_UPDATE=0
state=$WORK/.state
version=$(sed -n 's/^android_default_version_name = "\(.*\)"/\1/p' "$root/args.gn")
[[ -n $version ]] || { echo "could not read Chromium version from args.gn"; exit 1; }

say() { printf '\n==> %s\n' "$*"; }
done_p() { [[ -z ${FORCE:-} && -e $state/$1 ]]; }
mark() { mkdir -p "$state"; touch "$state/$1"; }
phase() { # phase <name> <function>
    if [[ -n ${ONLY:-} && $ONLY != "$1" ]]; then return; fi
    if done_p "$1"; then echo "skip: $1 (done)"; return; fi
    say "$1"; "$2"; mark "$1"
}

preflight() {
    [[ $(uname -m) == x86_64 ]] || { echo "x86_64 Linux required"; exit 1; }
    . /etc/os-release; [[ $ID == ubuntu ]] || echo "warning: only Ubuntu is tested"
    local mem_gb free_gb
    mem_gb=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)
    swap_gb=$(awk '/SwapTotal/ {print int($2/1024/1024)}' /proc/meminfo)
    mkdir -p "$WORK"; free_gb=$(df -BG --output=avail "$WORK" | tail -1 | tr -dc 0-9)
    echo "RAM ${mem_gb} GiB (+${swap_gb} GiB swap), free disk ${free_gb} GiB at $WORK"
    if (( mem_gb + swap_gb < 32 )) && [[ -z ${IGNORE_SPECS:-} ]]; then
        echo "Need 32 GiB RAM (or RAM+swap) for the CFI/LTO link. Add swap or set IGNORE_SPECS=1."; exit 1; fi
    if (( mem_gb < 32 )); then echo "warning: under 32 GiB RAM, the link step will lean on swap and be very slow"; fi
    if (( free_gb < 300 )) && [[ -z ${IGNORE_SPECS:-} ]]; then echo "Need ~300 GB free disk. IGNORE_SPECS=1 to override."; exit 1; fi
    if grep -q REPLACE_WITH "$root/E/args.gn.overlay"; then
        echo "E/args.gn.overlay still has placeholder cert digests. See E/SIGNING.md."; exit 1; fi
}

p_deps() {
    sudo apt-get update
    sudo apt-get install -y git git-lfs curl python3 python3-pip gperf zip unzip rsync \
        openjdk-21-jdk-headless lib32gcc-s1 libc6-i386 xz-utils
    git lfs install
}

p_fetch() {
    [[ -d $HOME/depot_tools ]] || git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$HOME/depot_tools"
    mkdir -p "$WORK/chromium"; cd "$WORK/chromium"
    if [[ ! -d src ]]; then fetch --nohooks android; fi
    cd src
    # Chromium's own dependency installer (Android build deps)
    sudo ./build/install-build-deps.sh --android --no-prompt || true
    git fetch --tags
    git rev-parse -q --verify "refs/tags/$version" >/dev/null || { echo "tag $version not found"; exit 1; }
}

p_patch() {
    cd "$WORK/chromium/src"
    git checkout -B "vanadium-e-$version" "$version"
    "$root/E/tools/apply-patches.sh"
}

p_sync() {
    cd "$WORK/chromium"
    gclient sync -D --with_branch_heads --with_tags --jobs "$JOBS"
}

p_subpatch() {
    cd "$WORK/chromium/src"
    "$root/E/tools/apply-subproject-patches.sh"
}

p_gn() {
    cd "$WORK/chromium/src"
    mkdir -p out/Default
    "$root/E/tools/build-args.sh" > out/Default/args.gn
    gn gen out/Default
}

p_build() {
    cd "$WORK/chromium/src"
    # Browser + its shared library + config app. (WebView is not needed for a standalone browser.)
    chrt -b 0 autoninja -C out/Default trichrome_chrome_64_32_apk trichrome_library_64_32_apk vanadium_config_apk
}

p_sign() {
    [[ -f $VANADIUM_E_KEYSTORE ]] || { echo "keystore not found: $VANADIUM_E_KEYSTORE (copy it here, see E/SIGNING.md)"; exit 1; }
    cd "$WORK/chromium/src"
    "$root/E/tools/generate-release" out
    say "Signed APKs:"; ls -1 out/Default/apks/release/
}

preflight
if [[ -n ${1:-} ]]; then ONLY=$1; FORCE=1; fi
phase deps p_deps
phase fetch p_fetch
phase patch p_patch
phase sync p_sync
phase subpatch p_subpatch
phase gn p_gn
phase build p_build
phase sign p_sign
say "Done. Install order: TrichromeLibrary, TrichromeChrome, VanadiumConfig (out/Default/apks/release/)."

#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Builds and signs Vanadium-E on Ubuntu (24.04 LTS recommended, x86_64).
#
#   E/tools/build-ubuntu.sh            run every phase (skips phases already done)
#   E/tools/build-ubuntu.sh <phase>    run one phase: deps | fetch | patch | sync | hooks | subpatch | lists | gn | build | sign
#   FORCE=1 ...                        re-run phases even if already done
#   IGNORE_SPECS=1 ...                 skip only the RAM/disk checks (build may be slow or run out of space)
#
# Environment (all optional):
#   WORK=~/vanadium-e-build                       where Chromium is checked out
#   VANADIUM_E_KEYSTORE=~/.vanadium-e/vanadium-e.keystore   signing key (copy it to this machine first)
#   VANADIUM_E_CERT_DIGEST=<sha256 of your signing cert>   needed unless E/args.gn.overlay defines it
#   BUILD_JOBS=<n>                                 compile parallelism (default: (RAM+swap GiB)/2, capped at nproc)
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
    if ! grep -q '^trichrome_certdigest *=' "$root/E/args.gn.overlay" && [[ ! ${VANADIUM_E_CERT_DIGEST:-} =~ ^[0-9a-f]{64}$ ]]; then
        echo "No signing cert digest. Run E/tools/cert-digest.sh, then: export VANADIUM_E_CERT_DIGEST=<that value>"; exit 1; fi
}

ensure_pgo_var() {
    # is_official_build needs V8's builtins PGO profiles and the Android AFDO profile; the gclient hooks
    # that download them are off unless this custom var is set in .gclient.
    local f=$WORK/chromium/.gclient
    grep -q checkout_pgo_profiles "$f" || sed -i 's/"custom_vars": *{}/"custom_vars": {"checkout_pgo_profiles": True}/' "$f"
    grep -q checkout_pgo_profiles "$f" || { echo "Could not enable PGO profiles: add \"custom_vars\": {\"checkout_pgo_profiles\": True} to the src solution in $f"; exit 1; }
}

p_deps() {
    sudo apt-get update
    sudo apt-get install -y git git-lfs curl python3 python3-pip gperf zip unzip rsync \
        openjdk-21-jdk-headless lib32gcc-s1 libc6-i386 xz-utils
    git lfs install
}

p_fetch() {
    [[ -d $HOME/depot_tools ]] || git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$HOME/depot_tools"
    # First run of gclient bootstraps depot_tools (python, cipd); needs depot_tools auto-update enabled.
    gclient --version
    mkdir -p "$WORK/chromium"; cd "$WORK/chromium"
    if [[ ! -d src ]]; then fetch --nohooks android; fi
    ensure_pgo_var
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
    ensure_pgo_var
    cd "$WORK/chromium"
    gclient sync -D --with_branch_heads --with_tags --jobs "$JOBS"
}

p_hooks() {
    # Re-runs the download hooks (V8 builtins PGO profile, Android AFDO profile) without re-syncing,
    # so it is safe after the subproject patches too.
    ensure_pgo_var
    cd "$WORK/chromium"
    gclient runhooks
    [[ -f src/v8/tools/builtins-pgo/profiles/x64.profile ]] || { echo "V8 PGO profile still missing after runhooks"; exit 1; }
}

p_subpatch() {
    cd "$WORK/chromium/src"
    "$root/E/tools/apply-subproject-patches.sh"
}

p_lists() {
    "$root/E/tools/download-filter-lists.sh" "$WORK/chromium/src"
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
    # Target names depend on the ABI config: *_64_32_apk exists only with a secondary ABI, otherwise *_64_apk.
    local all_targets targets=()
    all_targets=$(gn ls out/Default)
    for t in chrome library; do
        if grep -q ":trichrome_${t}_64_32_apk$" <<< "$all_targets"; then targets+=("trichrome_${t}_64_32_apk")
        elif grep -q ":trichrome_${t}_64_apk$" <<< "$all_targets"; then targets+=("trichrome_${t}_64_apk")
        else echo "no trichrome_${t} target found; closest:"; grep "trichrome_${t}" <<< "$all_targets" | head; exit 1; fi
    done
    targets+=(vanadium_config_apk)
    echo "building: ${targets[*]}"
    # Parallel jobs: ~2 GiB RAM+swap per compile job, otherwise the OOM killer ends the build partway.
    local mem_gb swap_gb jobs
    mem_gb=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)
    swap_gb=$(awk '/SwapTotal/ {print int($2/1024/1024)}' /proc/meminfo)
    jobs=${BUILD_JOBS:-$(( (mem_gb + swap_gb) / 2 ))}
    (( jobs > $(nproc) )) && jobs=$(nproc)
    (( jobs < 2 )) && jobs=2
    echo "build parallelism: -j $jobs (override with BUILD_JOBS); run inside tmux so a dropped SSH session cannot kill it"
    chrt -b 0 autoninja -j "$jobs" -C out/Default "${targets[@]}"
}

p_sign() {
    [[ -f $VANADIUM_E_KEYSTORE ]] || { echo "keystore not found: $VANADIUM_E_KEYSTORE (copy it to this machine)"; exit 1; }
    cd "$WORK/chromium/src"
    ls out/Default/apks/Trichrome*.apk out/Default/apks/Vanadium*.apk >/dev/null 2>&1 \
        || { echo "No built APKs in out/Default/apks/. The build did not finish; run the build phase first."; exit 1; }
    "$root/E/tools/generate-release" out
    ls out/Default/apks/release/*.apk >/dev/null 2>&1 || { echo "Signing produced no APKs (wrong passphrase?)."; exit 1; }
    say "Signed APKs:"; ls -1 out/Default/apks/release/
}

preflight
if [[ -n ${1:-} ]]; then ONLY=$1; FORCE=1; fi
phase deps p_deps
phase fetch p_fetch
phase patch p_patch
phase sync p_sync
phase hooks p_hooks
phase subpatch p_subpatch
phase lists p_lists
phase gn p_gn
phase build p_build
phase sign p_sign
say "Done. Install order: TrichromeLibrary, TrichromeChrome, VanadiumConfig (out/Default/apks/release/)."

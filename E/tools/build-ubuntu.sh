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
    # A first-time setup downloads Chromium (~300 GB total); with the checkout already present only the build output is needed.
    local need_gb=300
    [[ -d $WORK/chromium/src/.git ]] && need_gb=120
    if (( free_gb < need_gb )) && [[ -z ${IGNORE_SPECS:-} ]]; then echo "Need ~${need_gb} GB free disk, have ${free_gb}. IGNORE_SPECS=1 to override."; exit 1; fi
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
    # Browser + config app. (WebView is not needed for a standalone browser.)
    # Current Vanadium builds the browser as one standalone APK (vanadium_browser_apk). Older Vanadium
    # releases used the Trichrome layout (browser APK + shared library APK); keep supporting that.
    local all_targets targets=()
    all_targets=$(gn ls out/Default)
    if grep -q ":vanadium_browser_apk$" <<< "$all_targets"; then
        targets+=(vanadium_browser_apk)
    else
        for t in chrome library; do
            if grep -q ":trichrome_${t}_64_32_apk$" <<< "$all_targets"; then targets+=("trichrome_${t}_64_32_apk")
            elif grep -q ":trichrome_${t}_64_apk$" <<< "$all_targets"; then targets+=("trichrome_${t}_64_apk")
            else
                echo "no browser build target found (looked for vanadium_browser_apk and trichrome_${t}_*apk); candidates:"
                { grep -E "(vanadium|trichrome)_(browser|chrome|library)" <<< "$all_targets" | head -10; } || true
                exit 1
            fi
        done
    fi
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
    # In merged mode the config app's main ruleset must have been built from the list that is on disk now. The
    # compiled ruleset is consistently ~1.5x the size of its text (EasyList 1.5x, a 11 MB merged list 1.6x), so one
    # far smaller than the list means the config app was built before this list was in place (an older list, or
    # EasyList alone), and signing it would publish the wrong content. Relative to the list, so any list size works.
    local mode_file=vanadium/android_config/filter_lists/E-main-list-mode.txt cfg=out/Default/apks/VanadiumConfig.apk
    local main_list=vanadium/android_config/filter_lists/filter_lists_easylist.txt
    if [[ -f $mode_file && $(cat "$mode_file") == merged && -f $cfg && -f $main_list ]]; then
        local rsize lsize
        rsize=$(unzip -l "$cfg" unindexed_ruleset 2>/dev/null | awk '$4 == "unindexed_ruleset" {print $1}')
        lsize=$(wc -c < "$main_list")
        if (( ${rsize:-0} * 10 < lsize * 12 )); then
            echo "Lists are set to merged mode, but the config app's main ruleset (${rsize:-0} bytes) is too small for the main list on disk"
            echo "(${lsize} bytes of text; a ruleset built from it is normally about 1.5x that). The config app was built before this list"
            echo "was in place. Re-run the lists, gn and build phases, then sign again."
            exit 1
        fi
        echo "config app main ruleset: ${rsize} bytes for a ${lsize}-byte main list (consistent)"
    fi
    # The browser silently refuses an indexed ruleset with more than 1,000,000 flatbuffers tables and then blocks
    # nothing. Index the config app's main ruleset here with Chromium's own tool and refuse to sign if it is too big.
    if [[ -z ${SKIP_RULESET_CHECK:-} && -f $cfg ]]; then
        local chk=$WORK/ruleset-check
        mkdir -p "$chk"
        unzip -p "$cfg" unindexed_ruleset > "$chk/main.unindexed"
        if ! SRC="$WORK/chromium/src" OUT="$chk/work" "$root/E/tools/measure-ruleset.sh" "$chk/main.unindexed"; then
            echo "Refusing to sign: the config app's main ruleset failed the table-limit check above (see E/tools/count-ruleset-tables.py)."
            echo "Trim the main list (about 250,000 blocking rules at most), or set SKIP_RULESET_CHECK=1 to override at your own risk."
            exit 1
        fi
    fi
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

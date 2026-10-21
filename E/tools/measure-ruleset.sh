#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Measures what a filter list costs: how big the ruleset gets, and how long and how much memory it takes
# to build the index the browser creates on first start (and on every config update).
#
#   E/tools/measure-ruleset.sh <input> [<input> ...]
#
# Each <input> is one of:
#   an https:// URL        downloaded (with a browser-style user-agent) and converted
#   a filter list file     (ABP syntax) converted
#   a *.unindexed file     already a ruleset, e.g. pulled out of an APK:  unzip -p X.apk unindexed_ruleset > x.unindexed
# Several lists can be joined into one measurement with commas:  a.txt,b.txt
# Needs the host tools from a finished Chromium build; the indexing tool is built on first use.
# Environment: SRC=<chromium src dir> (default ~/vanadium-e-build/chromium/src), OUT=<scratch dir, default ~/ruleset-measure-work>
set -o errexit -o nounset -o pipefail
SRC=${SRC:-$HOME/vanadium-e-build/chromium/src}
OUT=${OUT:-$HOME/ruleset-measure-work}   # scratch space; keep your inputs somewhere else
export PATH=$HOME/depot_tools:$PATH
[[ $# -ge 1 ]] || { sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
[[ -e $OUT && ! -d $OUT ]] && { echo "OUT ($OUT) exists and is not a folder"; exit 1; }
mkdir -p "$OUT"
cd "$SRC"

# The tools must run on THIS machine. The Android build targets the phone's CPU, so a tool built in the default
# toolchain (out/Default/<tool>) is an arm64 binary that cannot run here; the host-toolchain copy sits in a
# subfolder such as out/Default/clang_x64/. Pick a binary whose ELF machine type matches the host.
host_machine() { case ${HOST_ARCH:-$(uname -m)} in x86_64|amd64) echo 3e00 ;; aarch64|arm64) echo b700 ;; *) echo unknown ;; esac; }
is_host_binary() {
    [[ $(od -An -tx1 -N4 "$1" 2>/dev/null | tr -d ' \n') == 7f454c46 ]] || return 1          # ELF magic
    [[ $(od -An -tx1 -j18 -N2 "$1" 2>/dev/null | tr -d ' \n') == "$(host_machine)" ]]       # e_machine
}
find_host_tool() {
    local f
    while IFS= read -r f; do
        if is_host_binary "$f"; then echo "$f"; return 0; fi
    done < <(find out/Default -name "$1" -type f -perm -u+x 2>/dev/null)
    return 0
}
conv=$(find_host_tool ruleset_converter)
[[ -n $conv ]] || { echo "no host-architecture ruleset_converter under $SRC/out/Default (finish a build first)"; exit 1; }
idx=$(find_host_tool subresource_indexing_tool)
if [[ -z $idx ]]; then
    # Build it in the same toolchain as ruleset_converter, i.e. the host one (folder name taken from its path).
    rel=${conv#out/Default/}
    if [[ $rel == */* ]]; then target="${rel%/*}/subresource_indexing_tool"; else target=subresource_indexing_tool; fi
    echo "building $target (host tool, one time)..." >&2
    autoninja -C out/Default "$target" >"$OUT/build-indexing-tool.log" 2>&1 \
        || { echo "could not build $target; see $OUT/build-indexing-tool.log. Targets available:" >&2; gn ls out/Default 2>/dev/null | grep -i indexing | head -5 >&2; exit 1; }
    idx=$(find_host_tool subresource_indexing_tool)
fi
[[ -n $idx ]] || { echo "no host-architecture subresource_indexing_tool found after building" >&2; exit 1; }
echo "using: $conv and $idx" >&2

timed() { # timed <label> <logfile> <cmd...>: runs the command, prints "<seconds> s, peak <MB> MB"
    local label=$1 log=$2; shift 2
    if /usr/bin/time --version 2>&1 | grep -q GNU; then
        /usr/bin/time -f "%e %M" -o "$log.time" "$@" >"$log.out" 2>"$log.err" || { echo "  $label FAILED (exit $?); log: $log.err" >&2; tail -3 "$log.err" >&2; return 1; }
        awk '{printf "%.1f s, peak %.0f MB\n", $1, $2/1024}' "$log.time"
    else
        local s=$SECONDS; "$@" >"$log.out" 2>"$log.err" || { echo "  $label FAILED (exit $?); log: $log.err" >&2; tail -3 "$log.err" >&2; return 1; }
        echo "$(( SECONDS - s )) s (install 'time' for peak memory: sudo apt install time)"
    fi
}
human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1 B"; }

printf '\n%-24s %9s %10s %10s  %-22s %-22s %8s\n' "input" "text" "unindexed" "indexed" "convert" "index" "skipped"
for spec in "$@"; do
    label=$(basename "${spec%%,*}"); label=${label%.txt}; label=${label%.unindexed}; label=${label//[^A-Za-z0-9._-]/_}
    [[ $spec == *,* ]] && label="${label}+more"
    work=$OUT/run-$label
    [[ -e $work && ! -d $work ]] && { echo "$work exists and is not a folder; choose another OUT"; exit 1; }
    mkdir -p "$work"; text=0; conv_res="-"; skipped="-"
    echo "measuring $label ..." >&2
    if [[ $spec == *.unindexed ]]; then
        unindexed=$spec
    else
        files=()
        IFS=',' read -ra parts <<< "$spec"
        for p in "${parts[@]}"; do
            if [[ $p == https://* ]]; then
                f=$work/$(echo "$p" | cksum | cut -d' ' -f1).txt
                curl -fsL -m 300 -A "Mozilla/5.0" -o "$f" "$p" || { echo "  -> $label skipped: download failed: $p" >&2; continue 2; }
                files+=("$f")
            else
                [[ -f $p ]] || { echo "  -> $label skipped: file not found: $p" >&2; continue 2; }
                files+=("$p")
            fi
        done
        for f in "${files[@]}"; do text=$(( text + $(wc -c < "$f") )); done
        unindexed=$work/ruleset.unindexed
        conv_res=$(timed convert "$work/convert" "$conv" --input_format=filter-list --output_format=unindexed-ruleset \
                   --input_files="$(IFS=,; echo "${files[*]}")" --output_file="$unindexed") || { echo "  -> $label skipped: conversion failed" >&2; continue; }
        skipped=$(grep -c "error:" "$work/convert.err" 2>/dev/null || true)
    fi
    indexed=$work/ruleset.indexed
    idx_res=$(timed index "$work/index" "$idx" "$unindexed" "$indexed") || { echo "  -> $label skipped: indexing failed" >&2; continue; }
    printf '%-24s %9s %10s %10s  %-22s %-22s %8s\n' "${label:0:24}" "$(human "$text")" "$(human "$(wc -c < "$unindexed")")" \
        "$(human "$(wc -c < "$indexed")")" "$conv_res" "$idx_res" "$skipped"
done
echo
echo "'skipped' = rules the converter could not parse (unsupported options); harmless."
echo "'indexed' is the size of the file the browser maps into memory; 'index' is what building it costs on THIS machine."
echo "A phone is slower than a build workstation, so treat the index time here as a lower bound."

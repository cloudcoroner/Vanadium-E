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
# Environment: SRC=<chromium src dir> (default ~/vanadium-e-build/chromium/src), OUT=<scratch dir>
set -o errexit -o nounset -o pipefail
SRC=${SRC:-$HOME/vanadium-e-build/chromium/src}
OUT=${OUT:-$HOME/ruleset-measure}
export PATH=$HOME/depot_tools:$PATH
[[ $# -ge 1 ]] || { sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
mkdir -p "$OUT"
cd "$SRC"

find_tool() { find out/Default -name "$1" -type f -perm -u+x 2>/dev/null | head -1; }
conv=$(find_tool ruleset_converter)
[[ -n $conv ]] || { echo "ruleset_converter not found under $SRC/out/Default (finish a build first)"; exit 1; }
idx=$(find_tool subresource_indexing_tool)
if [[ -z $idx ]]; then
    echo "building subresource_indexing_tool (one time)..."
    autoninja -C out/Default subresource_indexing_tool >"$OUT/build-indexing-tool.log" 2>&1 \
        || { echo "could not build it; see $OUT/build-indexing-tool.log. Targets available:"; gn ls out/Default 2>/dev/null | grep -i indexing | head -5; exit 1; }
    idx=$(find_tool subresource_indexing_tool)
fi
[[ -n $idx ]] || { echo "subresource_indexing_tool still not found after building"; exit 1; }

timed() { # timed <label> <logfile> <cmd...>: runs the command, prints "<seconds> s, peak <MB> MB"
    local label=$1 log=$2; shift 2
    if /usr/bin/time --version 2>&1 | grep -q GNU; then
        /usr/bin/time -f "%e %M" -o "$log.time" "$@" >"$log.out" 2>"$log.err" || { echo "$label failed; see $log.err"; tail -3 "$log.err"; return 1; }
        awk '{printf "%.1f s, peak %.0f MB\n", $1, $2/1024}' "$log.time"
    else
        local s=$SECONDS; "$@" >"$log.out" 2>"$log.err" || { echo "$label failed; see $log.err"; return 1; }
        echo "$(( SECONDS - s )) s (install 'time' for peak memory: sudo apt install time)"
    fi
}
human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1 B"; }

printf '\n%-24s %9s %10s %10s  %-22s %-22s %8s\n' "input" "text" "unindexed" "indexed" "convert" "index" "skipped"
for spec in "$@"; do
    label=$(basename "${spec%%,*}"); label=${label%.txt}; label=${label//[^A-Za-z0-9._-]/_}
    [[ $spec == *,* ]] && label="${label}+more"
    work=$OUT/$label; mkdir -p "$work"; text=0; conv_res="-"; skipped="-"
    if [[ $spec == *.unindexed ]]; then
        unindexed=$spec
    else
        files=()
        IFS=',' read -ra parts <<< "$spec"
        for p in "${parts[@]}"; do
            if [[ $p == https://* ]]; then
                f=$work/$(echo "$p" | cksum | cut -d' ' -f1).txt
                curl -fsL -m 300 -A "Mozilla/5.0" -o "$f" "$p" || { echo "download failed: $p"; continue 2; }
                files+=("$f")
            else
                [[ -f $p ]] || { echo "not found: $p"; continue 2; }
                files+=("$p")
            fi
        done
        for f in "${files[@]}"; do text=$(( text + $(wc -c < "$f") )); done
        unindexed=$work/ruleset.unindexed
        conv_res=$(timed convert "$work/convert" "$conv" --input_format=filter-list --output_format=unindexed-ruleset \
                   --input_files="$(IFS=,; echo "${files[*]}")" --output_file="$unindexed") || continue
        skipped=$(grep -c "error:" "$work/convert.err" 2>/dev/null || true)
    fi
    indexed=$work/ruleset.indexed
    idx_res=$(timed index "$work/index" "$idx" "$unindexed" "$indexed") || continue
    printf '%-24s %9s %10s %10s  %-22s %-22s %8s\n' "${label:0:24}" "$(human "$text")" "$(human "$(wc -c < "$unindexed")")" \
        "$(human "$(wc -c < "$indexed")")" "$conv_res" "$idx_res" "$skipped"
done
echo
echo "'skipped' = rules the converter could not parse (unsupported options); harmless."
echo "'indexed' is the size of the file the browser maps into memory; 'index' is what building it costs on THIS machine."
echo "A phone is slower than a build workstation, so treat the index time here as a lower bound."

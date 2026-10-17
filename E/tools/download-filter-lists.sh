#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Downloads the content-filter lists the Vanadium config app is built from (gitignored, so a fresh
# checkout has none). Uses Vanadium's own downloader (tools/filter_lists/filter_list_download.py).
# Usage: E/tools/download-filter-lists.sh <chromium src dir>
# Vanadium's repo does not publish its list sources; these are the public EasyList and regional
# lists. Edit the table to change sources. All 22 files must exist or the config app won't build.
set -o errexit -o nounset -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
dest=${1:?usage: $0 <chromium src dir>}/vanadium/android_config/filter_lists
[[ -d $dest ]] || { echo "not found: $dest (apply the patches first)"; exit 1; }

# Main ad/tracker ruleset source (E_MAIN_LIST):
#   official (default)  EasyList + EasyPrivacy from adblockplus.org
#   merged              one pre-merged, deduplicated list (E_MERGED_LIST_URL), which already contains EasyList and
#                       EasyPrivacy. The EasyPrivacy input then gets a comment-only file so the build file still works.
# Switching modes changes the ruleset content, so raise E/config-revision before releasing.
mode=${E_MAIN_LIST:-official}
merged_url=${E_MERGED_LIST_URL:-https://saeos.com/proxyfilters/adblock_merged.txt}
case $mode in official|merged) ;; *) echo "E_MAIN_LIST must be 'official' or 'merged' (got '$mode')"; exit 2 ;; esac
marker=$dest/E-main-list-mode.txt
if [[ -f $marker && $(cat "$marker") != "$mode" ]]; then
    echo "main list mode changed ($(cat "$marker") -> $mode): re-downloading the two main list files"
    rm -f "$dest/filter_lists_easylist.txt" "$dest/filter_lists_easyprivacy.txt"
fi
echo "$mode" > "$marker"

lists=(
 "@MAIN_LISTS@"
 "easylist_arabic https://easylist-downloads.adblockplus.org/Liste_AR.txt"
 "easylist_bulgaria https://stanev.org/abp/adblock_bg.txt"
 "easylist_china https://easylist-downloads.adblockplus.org/easylistchina.txt"
 "easylist_dutch https://easylist-downloads.adblockplus.org/easylistdutch.txt"
 "easylist_french https://easylist-downloads.adblockplus.org/liste_fr.txt"
 "easylist_germany https://easylist.to/easylistgermany/easylistgermany.txt"
 "easylist_hebrew https://raw.githubusercontent.com/easylist/EasyListHebrew/master/EasyListHebrew.txt"
 "easylist_indian https://easylist-downloads.adblockplus.org/indianlist.txt"
 "easylist_indonesia https://easylist-downloads.adblockplus.org/abpindo.txt"
 "easylist_italy https://easylist-downloads.adblockplus.org/easylistitaly.txt"
 "easylist_korean https://easylist-downloads.adblockplus.org/koreanlist.txt"
 "easylist_latvian https://raw.githubusercontent.com/Latvian-List/adblock-latvian/master/lists/latvian-list.txt"
 "easylist_lithuanian https://raw.githubusercontent.com/EasyList-Lithuania/easylist_lithuania/master/easylistlithuania.txt"
 "easylist_nordic https://raw.githubusercontent.com/DandelionSprout/adfilt/master/NorwegianExperimentalList%20alternate%20versions/NordicFiltersABP-Inclusion.txt"
 "easylist_polish https://raw.githubusercontent.com/MajkiIT/polish-ads-filter/master/polish-adblock-filters/adblock.txt"
 "easylist_portuguese https://easylist-downloads.adblockplus.org/easylistportuguese.txt"
 "easylist_romanian https://raw.githubusercontent.com/tcptomato/ROad-Block/master/road-block-filters-light.txt"
 "easylist_russian https://easylist-downloads.adblockplus.org/advblock.txt"
 "easylist_spanish https://easylist-downloads.adblockplus.org/easylistspanish.txt"
 "easylist_vietnam https://raw.githubusercontent.com/abpvn/abpvn/master/filter/abpvn_ublock.txt"
)

# Expand the main-list placeholder for the chosen mode.
expanded=()
for entry in "${lists[@]}"; do
    if [[ $entry == @MAIN_LISTS@ ]]; then
        if [[ $mode == merged ]]; then
            expanded+=("easylist $merged_url" "easyprivacy EMPTY")
        else
            expanded+=("easylist https://easylist-downloads.adblockplus.org/easylist.txt" \
                       "easyprivacy https://easylist-downloads.adblockplus.org/easyprivacy.txt")
        fi
    else
        expanded+=("$entry")
    fi
done
lists=("${expanded[@]}")

failed=0
manifest=$dest/E-manifest.txt   # what went into this build (name, size, sha256, source); gitignored
: > "$manifest"
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
for entry in "${lists[@]}"; do
    name=${entry%% *}; url=${entry#* }
    out=$dest/filter_lists_$name.txt
    if [[ $url == EMPTY ]]; then
        printf '! intentionally empty: the merged main list already contains this list\n' > "$out"
        echo "empty $name (merged mode)"
        echo "$name (empty, covered by the merged main list)" >> "$manifest"
        continue
    fi
    if [[ -s $out && -z ${FORCE:-} ]]; then
        echo "have  $name"
    elif python3 "$root/tools/filter_lists/filter_list_download.py" --urls "$url" --output "$out.part" 2>"$out.err" && [[ -s $out.part ]]; then
        mv "$out.part" "$out"; rm -f "$out.err"; echo "ok    $name ($(wc -c < "$out") bytes)"
    else
        echo "FAIL  $name  $url"; tail -2 "$out.err" | sed 's/^/        /'; rm -f "$out.part" "$out.err"; failed=1
        continue
    fi
    echo "$(sha256 "$out")  $(wc -c < "$out") bytes  $name  $url" >> "$manifest"
done
(( failed )) && { echo "Some lists failed to download. Re-run to retry only the missing ones."; exit 1; }
echo "all ${#lists[@]} filter lists present (main list mode: $mode)"

#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Downloads the content-filter lists the Vanadium config app is built from (gitignored, so a fresh
# checkout has none). Uses Vanadium's own downloader (tools/filter_lists/filter_list_download.py).
# Usage: E/tools/download-filter-lists.sh <chromium src dir>
# Vanadium's repo does not publish its list sources; these are the public EasyList and regional
# lists. Edit the table to change sources. All 21 files must exist or the config app won't build.
set -o errexit -o nounset -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
dest=${1:?usage: $0 <chromium src dir>}/vanadium/android_config/filter_lists
[[ -d $dest ]] || { echo "not found: $dest (apply the patches first)"; exit 1; }

lists=(
 "easylist https://easylist.to/easylist/easylist.txt"
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

failed=0
for entry in "${lists[@]}"; do
    name=${entry%% *}; url=${entry#* }
    out=$dest/filter_lists_$name.txt
    if [[ -s $out && -z ${FORCE:-} ]]; then echo "have  $name"; continue; fi
    if python3 "$root/tools/filter_lists/filter_list_download.py" --urls "$url" --output "$out.part" 2>"$out.err" && [[ -s $out.part ]]; then
        mv "$out.part" "$out"; rm -f "$out.err"; echo "ok    $name ($(wc -c < "$out") bytes)"
    else
        echo "FAIL  $name  $url"; tail -2 "$out.err" | sed 's/^/        /'; rm -f "$out.part" "$out.err"; failed=1
    fi
done
(( failed )) && { echo "Some lists failed to download. Re-run to retry only the missing ones."; exit 1; }
echo "all ${#lists[@]} filter lists present"

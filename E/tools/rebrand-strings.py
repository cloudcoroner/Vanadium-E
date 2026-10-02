#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Rewrite the visible product name "Vanadium" to "Vanadium-E" in GRIT string files.

Usage: rebrand-strings.py <chromium src dir>
Run after the Vanadium patches. Only message text is changed: XML tags, attributes
(e.g. desc=), comments, file names (Vanadium.png), paths (Vanadium/Vanadium) and
hyphenated identifiers (Vanadium-OS) are left alone. Doing this at apply time, instead of
as a static patch, means upstream string changes never conflict.
Note: GRIT message IDs derive from the English text, so translations of the changed
messages no longer match and those messages display in English.
"""
import re, subprocess, sys

SKIP = re.compile(r'(<!--.*?-->|<[^>]*>)', re.S)  # comments and tags: never touched
NAME = re.compile(r"(?<![\w/.@-])Vanadium(?![\w/@-]|\.\w)")


def rebrand(text):
    parts = SKIP.split(text)
    # re.split with one capture group: odd indexes are comments/tags
    for i in range(0, len(parts), 2):
        parts[i] = NAME.sub("Vanadium-E", parts[i])
    return "".join(parts)


def main(src):
    files = subprocess.check_output(
        ["git", "-C", src, "ls-files", "*.grd", "*.grdp"], text=True).split()
    changed = replaced = 0
    for f in files:
        path = f"{src}/{f}"
        with open(path, encoding="utf-8") as fh:
            old = fh.read()
        if "Vanadium" not in old:
            continue
        new = rebrand(old)
        if new != old:
            replaced += new.count("Vanadium-E") - old.count("Vanadium-E")
            changed += 1
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(new)
    print(f"rebranded {replaced} occurrences in {changed} files")


if __name__ == "__main__":
    main(sys.argv[1])

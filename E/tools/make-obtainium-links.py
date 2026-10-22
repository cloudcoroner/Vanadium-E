#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Prints Obtainium "add app" links for the two Vanadium-E APKs (browser and config app).

Format: obtainium://apps/<url-encoded JSON array> (https://wiki.obtainium.imranr.dev/deep_links/); each entry has the
fields Obtainium's own "share config link" emits, with `additionalSettings` as a JSON string. Each entry tracks the same
GitHub repo but only the APK its filter matches. Version detection is off, so Obtainium compares release tags instead of
trying to reconcile them with the installed version names. Tapping a link shows a confirmation with the raw JSON first.

Usage: make-obtainium-links.py [repo-url]      (default https://github.com/cloudcoroner/Vanadium-E)
"""
import json, re, sys, urllib.parse

repo = sys.argv[1] if len(sys.argv) > 1 else "https://github.com/cloudcoroner/Vanadium-E"
author = repo.rstrip('/').split('/')[-2]


def entry(package, name, apk):
    settings = {"apkFilterRegEx": "^" + re.escape(apk) + "$", "versionDetection": False}
    return {"id": package, "url": repo, "author": author, "name": name, "preferredApkIndex": 0,
            "additionalSettings": json.dumps(settings, separators=(',', ':'))}


def enc(obj):
    return urllib.parse.quote(json.dumps(obj, separators=(',', ':')), safe='')


apps = [entry("app.vanadiume.browser", "Vanadium-E", "VanadiumBrowser.apk"),
        entry("app.vanadiume.config", "Vanadium-E Config", "VanadiumConfig.apk")]
print("Both apps in one link:\n" + "obtainium://apps/" + enc(apps) + "\n")
for a in apps:
    print(f"{a['name']} only:\n" + "obtainium://app/" + enc(a) + "\n")

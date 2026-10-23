#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Prints Obtainium "add app" links for the two Vanadium-E APKs (browser and config app).

Format: obtainium://apps/<url-encoded JSON array> (https://wiki.obtainium.imranr.dev/deep_links/); each entry has the
fields Obtainium's own "share config link" emits, with `additionalSettings` as a JSON string. Each entry tracks the same
GitHub repo but only the APK its filter matches. Releases are tagged <browser version>-<config version>, e.g.
156.0.8078.47.0-22004, and each entry extracts ITS OWN version from the tag with a regex (browser: the leading five-part
number; config app: the number after the dash). Those strings are exactly the versionName the installed apps report, so
Obtainium sees an app as up to date only when it truly has that version, and shows real version numbers. Tapping a link
shows a confirmation with the raw JSON first.

GitHub does not make custom-scheme links clickable, so the README links go through Obtainium's redirect page
(https://apps.obtainium.imranr.dev/redirect?r=...), which only accepts single-app links (obtainium://app/...) and
rejects the bulk obtainium://apps/... form. So the README gets one redirect link per APK; the bulk link is printed
too for pasting into a phone's browser or a message, where it works directly.

Usage: make-obtainium-links.py [repo-url]      (default https://github.com/cloudcoroner/Vanadium-E)
"""
import json, re, sys, urllib.parse

repo = sys.argv[1] if len(sys.argv) > 1 else "https://github.com/cloudcoroner/Vanadium-E"
author = repo.rstrip('/').split('/')[-2]


def entry(package, name, apk, version_regex, group):
    settings = {"apkFilterRegEx": "^" + re.escape(apk) + "$", "versionDetection": True,
                "versionExtractionRegEx": version_regex, "matchGroupToUse": group}
    return {"id": package, "url": repo, "author": author, "name": name, "preferredApkIndex": 0,
            "additionalSettings": json.dumps(settings, separators=(',', ':'))}


def enc(obj):
    return urllib.parse.quote(json.dumps(obj, separators=(',', ':')), safe='')


apps = [entry("app.vanadiume.browser", "Vanadium-E", "VanadiumBrowser.apk", r"^[0-9]+(?:\.[0-9]+){4}", ""),
        entry("app.vanadiume.config", "Vanadium-E Config", "VanadiumConfig.apk", r"-([0-9]+)$", "1")]
REDIRECT = "https://apps.obtainium.imranr.dev/redirect?r="
links = {a["name"]: "obtainium://app/" + enc(a) for a in apps}

print("README markdown (works on GitHub; each link opens Obtainium's add-app confirmation on a phone):\n")
print("Install with Obtainium (tap on the phone, one link per app): " +
      " | ".join(f"[{name}]({REDIRECT}{link})" for name, link in links.items()) + "\n")
print("Both apps in one link (bare custom-scheme link: paste into a phone's browser or a message, not into GitHub):\n")
print("obtainium://apps/" + enc(apps) + "\n")

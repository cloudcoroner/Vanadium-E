# Vanadium-E

A separately installable build of [Vanadium](https://github.com/GrapheneOS/Vanadium) with
customized default configuration and default profile. No Vanadium code is modified.

Vanadium-E's aim is to add an additional layer of configs to Vanadium that provide an ephemeral browser option for users. Users will essentially have two Vanadium browsers on GrapheneOS. By setting Vanadium-E as the default browser running along side of Vanadium on GrapheneOS, links in emails and instant messages are opened in an ephemeral space with a heightened level of DNS security, URL filtering and proxied search. History, saved passwords, form-filling and other extended or saved browser session features are also disabled. DOH and search settings can be modified by the user and will not be reset during an upgrade.

Additional block-lists have been merged with Vanadium's built-in ad and privacy block lists: tracking/analytics, crypto-jacking and scam site lists. Chromium/Vanadium has a hard limit of how large the built-in block list can be. A random sample of available lists were compared to Vanadium-E's DOH security configuration to select the best combination. These were the lists that either verlapped the least with our DOH configuration or were small enough to fit with no memory penalty.

If a web site is opened in Vanadium-E and it should open in Vanadium, tap the menu and Share, Open in Vanadium.

Vanadium-E's build is a set of config settings as patches packaged after Vanadium's patches are applied. Claude is used to ensure Vanadium-E patches do not impact the effectiveness of upstream Vanadium patches.

## Layout
- Vanadium's own files (`patches/`, `args.gn`, `generate-release`, `README.md`, ...) are left as upstream has them, so syncing from Vanadium doesn't conflict. The one exception is `.gitignore`, where a few lines keep signing keys out of git. Everything Vanadium-E adds is in `E/`, `.github/` and the two notice files (`README-Vanadium-E.md`, `NOTICE-Vanadium-E`).
- `E/patches/` – Chromium patches applied after Vanadium's (defaults, names, icons, incognito start, ...). `E/patches/README.md` maps each setting to its patch.
- `E/subprojects_patches/` – patches for the search engine data submodule (Startpage first on every regional list).
- `E/args.gn.overlay` – build arguments that replace Vanadium's (package names `app.vanadiume.*`, `ext_version_increment`). The signing certificate digest is supplied at build time through `VANADIUM_E_CERT_DIGEST`.
- `E/config-revision` – added to upstream's config app version (upstream x 100 + this number). **Raise it whenever the filter list content changes**, otherwise phones keep the old indexed rules.
- `E/branding/` – launcher icon sources and the script that generates them.
- `.github/workflows/` – `sync-upstream.yml` (daily: merges upstream, checks that the patches still apply, opens a pull request) and `check-patches.yml` (runs the same patch check on pushes and pull requests).

### E/tools
Build and release
- `build-ubuntu.sh` – builds and signs on Ubuntu: dependencies, Chromium checkout, patches, filter lists, build, signing. Resumable, one phase at a time.
- `apply-patches.sh`, `apply-subproject-patches.sh` – the two patch phases, before and after `gclient sync`.
- `build-args.sh` – generates `args.gn`: Vanadium's, plus the overlay, certificate digest and config version.
- `create-keystore.sh`, `cert-digest.sh`, `generate-release` – create the signing key, print its certificate digest, and sign the APKs (a copy of upstream's signing script using the Vanadium-E key).
- `publish-release.sh` – creates the GitHub release (a draft by default, `--prerelease` for test builds) after verifying the APK signatures; the notes carry checksums and the filter-list sources.
- `make-obtainium-links.py` – prints Obtainium links that add the browser and config APKs.
- `rebrand-strings.py` – renames the visible product name to "Vanadium-E" in string files when patches are applied.

Filter lists
- `download-filter-lists.sh` – downloads the lists the config app is built from. The main list is the merged list (default, from `E_MERGED_LIST_URL`) or EasyList plus EasyPrivacy (`E_MAIN_LIST=official`).
- `measure-ruleset.sh`, `count-ruleset-tables.py` – measure a list's size, indexing time and memory, and its index table count. The browser rejects an index over 1,000,000 tables and then blocks nothing; the signing step runs this check.
- `measure-dns-overlap.py` – estimates how much of each blocklist Cloudflare's malware-blocking DNS already covers.

Maintenance
- `check-patches.sh` – checks that the patches still apply on top of Vanadium's at the target Chromium version, without a full checkout.
- `sync-upstream.sh` – merges GrapheneOS/Vanadium into this repo.

License: GPL-2.0 only, see `NOTICE-Vanadium-E`.

Install with Obtainium (tap on the phone, one link per app): [Vanadium-E](https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22app.vanadiume.browser%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Fcloudcoroner%2FVanadium-E%22%2C%22author%22%3A%22cloudcoroner%22%2C%22name%22%3A%22Vanadium-E%22%2C%22preferredApkIndex%22%3A0%2C%22additionalSettings%22%3A%22%7B%5C%22apkFilterRegEx%5C%22%3A%5C%22%5EVanadiumBrowser%5C%5C%5C%5C.apk%24%5C%22%2C%5C%22versionDetection%5C%22%3Afalse%7D%22%7D) | [Vanadium-E Config](https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22app.vanadiume.config%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Fcloudcoroner%2FVanadium-E%22%2C%22author%22%3A%22cloudcoroner%22%2C%22name%22%3A%22Vanadium-E%20Config%22%2C%22preferredApkIndex%22%3A0%2C%22additionalSettings%22%3A%22%7B%5C%22apkFilterRegEx%5C%22%3A%5C%22%5EVanadiumConfig%5C%5C%5C%5C.apk%24%5C%22%2C%5C%22versionDetection%5C%22%3Afalse%7D%22%7D)

# Vanadium-E

A separately installable build of [Vanadium](https://github.com/GrapheneOS/Vanadium) with
customized default configuration and default profile. No Vanadium code is modified.

Vanadium-E's aim is to add an additional layer of configs to Vanadium that provide an ephemeral browser option for users. Users will essentially have two Vanadium browsers on GrapheneOS. By setting Vanadium-E as the default browser running along side of Vanadium on GrapheneOS, links in emails and instant messages are opened in an ephemeral space with a heightened level of DNS security, URL filtering and proxied search. History, saved passwords, form-filling and other extended or saved browser session features are also disabled. DOH and search settings can be modified by the user and will not be reset during an upgrade.

Additional block-lists have been merged with Vanadium's built-in ad and privacy block lists: tracking/analytics, crypto-jacking and scam site lists. Chromium/Vanadium has a hard limit of how large the built-in block list can be. A random sample of available lists were compared to Vanadium-E's DOH security configuration to select the best combination. These were the lists that either verlapped the least with our DOH configuration or were small enough to fit with no memory penalty.

If a web site is opened in Vanadium-E and it should open in Vanadium, tap the menu and Share, Open in Vanadium.

Vanadium-E's build is a set of config settings as patches packaged after Vanadium's patches are applied. Claude is used to ensure Vanadium-E patches do not impact the effectiveness of upstream Vanadium patches.

## Layout
- Everything upstream (`patches/`, `args.gn`, ...) is untouched, so syncing never conflicts.
- `E/args.gn.overlay` – build arg overrides (package names, signing digest).
- `E/patches/` – extra Chromium patches (defaults); `E/subprojects_patches/` – patches for the search engine data submodule. See `E/patches/README.md` for the settings map.
- `E/tools/` – `sync-upstream.sh`, `build-args.sh`, `apply-patches.sh` / `apply-subproject-patches.sh`.
- `.github/workflows/sync-upstream.yml` – daily upstream merge PR.

License: GPL-2.0 only, see `NOTICE-Vanadium-E`.

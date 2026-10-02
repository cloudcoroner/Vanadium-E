# Vanadium-E

A separately installable build of [Vanadium](https://github.com/GrapheneOS/Vanadium) with
customized default configuration and default profile. No Vanadium code is modified.

## Layout
- Everything upstream (`patches/`, `args.gn`, ...) is untouched, so syncing never conflicts.
- `E/args.gn.overlay` – build arg overrides (package names, signing digest).
- `E/patches/` – extra Chromium patches (defaults); `E/subprojects_patches/` – patches for the search engine data submodule. See `E/patches/README.md` for the settings map.
- `E/tools/` – `sync-upstream.sh`, `build-args.sh`, `apply-patches.sh` / `apply-subproject-patches.sh`.
- `.github/workflows/sync-upstream.yml` – daily upstream merge PR.

## Build (Ubuntu, x86_64)
Needs 32 GiB+ RAM (CFI/LTO link), ~300 GB free disk and several hours.

1. Finish `E/SIGNING.md` (key created, digest in `E/args.gn.overlay`, keystore copied to the build machine).
2. `git clone https://github.com/cloudcoroner/Vanadium-E.git && cd Vanadium-E`
3. `E/tools/build-ubuntu.sh` – installs deps, fetches Chromium at the version in `args.gn`, applies
   Vanadium then Vanadium-E patches, builds the browser, library and config APKs, and signs them.
   It is resumable; run one phase with `E/tools/build-ubuntu.sh <deps|fetch|patch|sync|subpatch|gn|build|sign>`.
4. Signed APKs: `~/vanadium-e-build/chromium/src/out/Default/apks/release/`.
   Install `TrichromeLibrary.apk`, `TrichromeChrome.apk`, then `VanadiumConfig.apk` (e.g. `adb install`).

Build steps follow GrapheneOS's [browser build docs](https://grapheneos.org/build#browser-and-webview).

## Sync
`E/tools/sync-upstream.sh`, then rebuild; fix any E patch that no longer applies.

License: GPL-2.0 only, see `NOTICE-Vanadium-E`.

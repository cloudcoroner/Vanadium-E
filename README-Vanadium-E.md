# Vanadium-E

A separately installable build of [Vanadium](https://github.com/GrapheneOS/Vanadium) with
customized default configuration and default profile. No Vanadium code is modified.

## Layout
- Everything upstream (`patches/`, `args.gn`, ...) is untouched, so syncing never conflicts.
- `E/args.gn.overlay` – build arg overrides (package names, signing digest).
- `E/patches/` – extra Chromium patches (defaults); `E/subprojects_patches/` – patches for the search engine data submodule. See `E/patches/README.md` for the settings map.
- `E/tools/` – `sync-upstream.sh`, `build-args.sh`, `apply-patches.sh`.
- `.github/workflows/sync-upstream.yml` – daily upstream merge PR.

## Build
1. Check out Chromium at the version in `args.gn` (`android_default_version_name`).
2. From that checkout: `/path/to/Vanadium-E/E/tools/apply-patches.sh`
3. `mkdir -p out/Default && /path/to/Vanadium-E/E/tools/build-args.sh > out/Default/args.gn`
4. `gn gen out/Default && autoninja -C out/Default chrome_public_apk` (see GrapheneOS build docs).
5. Sign with your own key: see `E/SIGNING.md`.

## Sync
`E/tools/sync-upstream.sh`, then rebuild; fix any E patch that no longer applies.

License: GPL-2.0 only, see `NOTICE-Vanadium-E`.

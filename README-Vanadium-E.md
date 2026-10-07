# Vanadium-E

A separately installable build of [Vanadium](https://github.com/GrapheneOS/Vanadium) with
customized default configuration and default profile. No Vanadium code is modified.

## Layout
- Everything upstream (`patches/`, `args.gn`, ...) is untouched, so syncing never conflicts.
- `E/args.gn.overlay` – build arg overrides (package names, signing digest).
- `E/patches/` – extra Chromium patches (defaults); `E/subprojects_patches/` – patches for the search engine data submodule. See `E/patches/README.md` for the settings map.
- `E/tools/` – `sync-upstream.sh`, `build-args.sh`, `apply-patches.sh` / `apply-subproject-patches.sh`.
- `.github/workflows/sync-upstream.yml` – daily upstream merge PR.

License: GPL-2.0 only, see `NOTICE-Vanadium-E`.

# Vanadium-E patches

Chromium-source patches for Vanadium-E's default configuration and default
profile, applied *after* all Vanadium patches. Name them `E-NNNN-description.patch`
(git format-patch output). Never edit files in `../../patches/`.

Typical candidates (mirror how Vanadium does it, e.g. `patches/0117-set-default-search-engine-to-DuckDuckGo.patch`,
`0079-disable-third-party-cookies-by-default.patch`):
- default search engine, homepage, new-tab behavior
- default pref values (`chrome/browser/prefs/browser_prefs.cc`, pref registrations)
- app name / icons (`E` branding), applied on top of `0004-Vanadium-branding.patch`

When upstream changes break an E patch, rebase the E patch only.

# Vanadium-E patches

Chromium-source patches applied *after* all Vanadium patches by `E/tools/apply-patches.sh`.
Named `E-NNNN-description.patch` (git format-patch output). Never edit `../../patches/`.
Patches for the `third_party/search_engines_data/resources` submodule live in
`../subprojects_patches/`.

When upstream changes break an E patch, rebase only that E patch.

## Settings map (ephemeral, start-clean profile)

| Requested setting | How it's met |
|---|---|
| Always open in incognito | `E-0006` (initial tab is incognito) + `E-0002` (external links open in incognito) |
| Search engine: Startpage | `E-0001` + `subprojects_patches/.../E-0001` (Startpage first on every regional list) |
| Block third-party cookies | already Vanadium `0079` |
| Do Not Track on | already Vanadium `0125` |
| Close tabs on exit on | `E-0002` |
| Open external links in incognito on | `E-0002` |
| Safe Browsing off | already Vanadium `0087` |
| Always use secure connections (warn on public + private sites) | already Vanadium `0119` (strict HTTPS-only; balanced mode stays off) |
| Secure DNS on, `https://security.cloudflare-dns.com/dns-query` | `E-0003` |
| Access payment methods off | already Vanadium `0081` |
| Save passwords / auto sign-in off | `E-0004` |
| Save and fill payment methods / security codes off | `E-0005` |
| Save and fill addresses off | `E-0005` |

| Distinct launcher icon (incl. themed/monochrome) | `E-0007` (violet ring with an "E"; the themed icon has the E cut out of its center; PNGs regenerate with `E/branding/generate-icons.py`) |
| Launcher name "Vanadium-E" | `E-0008` (app label and widget titles) |

Not covered: the "Autofill settings" section of the request was empty.

Notes
- Defaults only: a user can still flip any toggle in Settings.
- `E-0006` applies to windows holding both regular and incognito tabs (phones). Where the
  OS opens incognito as a separate window (some tablet/desktop modes) it is skipped.
- Incognito tabs block screenshots by default (Android `FLAG_SECURE`).

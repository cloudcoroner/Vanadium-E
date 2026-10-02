# Signing Vanadium-E

Android only installs an update over an existing app if both are signed with the **same key**.
Vanadium-E needs its own key, separate from GrapheneOS's Vanadium key.

## One-time setup

1. Install a JDK (macOS ships only a `keytool` stub): `brew install --cask temurin`
2. Create the key (stored at `~/.vanadium-e/vanadium-e.keystore`, outside the repo):
   `E/tools/create-keystore.sh` — choose a strong passphrase when prompted.
3. Put its certificate digest into the build args: `E/tools/cert-digest.sh --write`
4. Commit the changed `E/args.gn.overlay` (a digest is public, not secret).

## Rules

- **Back up** `vanadium-e.keystore` and its passphrase (password manager + an offline copy).
  If you lose them you can never ship an update that installs over existing users' installs.
- **Never commit** the keystore (`.gitignore` blocks `*.keystore`, `*.jks`, `*.p12`, `*.pem`).
- Don't share the passphrase or keystore with CI unless you deliberately want CI to release.

## Signing a build

From the Chromium checkout, after building: `/path/to/Vanadium-E/E/tools/generate-release out`
(same as Vanadium's `generate-release`, but using the Vanadium-E key). Output lands in
`out/Default/apks/release/`. Install the signed APKs, not the unsigned build output.

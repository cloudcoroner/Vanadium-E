Vanadium-E is a fork of the GrapheneOS native browser Vanadium (readme below). Vanadium-E's aim is to keep Vanadium exactly as is but layer an additional set of configs on top that add an ephemeral browser option for users. Vanadium-E is meant to run along side Vanadium on GrapheneOS and be the default browser so that links in emails and instant messages are opened in an ephemeral space where the user can set a heightened level of DNS security, should they so choose.

Vanadium is a privacy and security hardened variant of Chromium providing the WebView (used by
other apps to render web content) and standard browser for [GrapheneOS](https://grapheneos.org).
It depends on hardening and compatibility fixes in GrapheneOS rather than reinventing the wheel
inside Vanadium. For example, GrapheneOS already provides a hardened malloc implementation so
there's no need for Vanadium to replace it. Similarly, it can deploy security features causing
breakage on other operating systems due to the ability to fix compatibility problems in the OS.

See [the official build documentation](https://grapheneos.org/build#browser-and-webview) for build
instructions. See the [Vanadium section of our GrapheneOS features overview](https://grapheneos.org/features#vanadium) and the [web browsing section of 
our usage guide](https://grapheneos.org/usage#web-browsing) for more information about Vanadium.

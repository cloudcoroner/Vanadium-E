Vanadium-E is a fork of the GrapheneOS native browser Vanadium (readme below). Vanadium-E's aim is to keep Vanadium exactly as is while adding an additional layer of configs that provide a separate browser option for users that is ephemeral. Users will essentially have two Vanadium browsers on GrapheneOS. By setting Vanadium-E as the default browser running along side of Vanadium on GrapheneOS, links in emails and instant messages are opened in an ephemeral space with a heightened level of DNS security, URL filtering and proxied search. History, saved passwords, form-filling and other extended or saved browser session features are also disabled. DOH and search settings can be modified by the user and will not be reset  during an upgrade.

Additional block-lists have been merged with Vanadium's built-in ad and privacy block lists: tracking/analytics, crypto-jacking and scam site lists. Chromium/Vanadium has a hard limit of how large the built-in block list can be. A random sample of available lists were compared to Vanadium-E's DOH security configuration to select the best combination. These were the lists that our DOH configuration overlapped with the least and shipped the least amount of dead domains.

If a web site is opened in Vanadium-E and it should open in Vanadium, tap the menu and Share, Open in Vanadium.

Vanadium-E's build is a set of config settings as patches packaged after Vanadium's patches are applied. Claude is used to ensure Vanadium-E patches do not impact the effectiveness of upstream Vanadium patches.

Vanadium is a privacy and security hardened variant of Chromium providing the WebView (used by
other apps to render web content) and standard browser for [GrapheneOS](https://grapheneos.org).
It depends on hardening and compatibility fixes in GrapheneOS rather than reinventing the wheel
inside Vanadium. For example, GrapheneOS already provides a hardened malloc implementation so
there's no need for Vanadium to replace it. Similarly, it can deploy security features causing
breakage on other operating systems due to the ability to fix compatibility problems in the OS.

See [the official build documentation](https://grapheneos.org/build#browser-and-webview) for build
instructions. See the [Vanadium section of our GrapheneOS features overview](https://grapheneos.org/features#vanadium) and the [web browsing section of 
our usage guide](https://grapheneos.org/usage#web-browsing) for more information about Vanadium.

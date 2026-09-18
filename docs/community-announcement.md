<!--
First community post for the NS8 GoPhish module, written in the style
of https://community.nethserver.org/t/ns8-forgejo-testing/28554 (first post).
Paste into a new topic on community.nethserver.org, category "App", tag "ns8".
Fill in the wiki link once the page is published.
-->

# NS8 GoPhish (testing)

Hi all,

I've built an NS8 module for [GoPhish](https://getgophish.com/) — the open-source phishing-simulation framework, for running your own security-awareness tests.

It's in my community repository. To try it, add the repo once:

```
api-cli run add-repository --data '{"name":"tebbiworld","url":"https://raw.githubusercontent.com/tebbiworld/ns8-repo/main/ns8/updates/","status":true,"testing":false}'
```

then install **GoPhish** from the Software Center. (Or straight from the image: `add-module ghcr.io/tebbiworld/gophish:latest 1`.)

What it does:

* Built by the module straight from the official GoPhish release ZIP — no third-party image off Docker Hub
* Admin server (web UI + REST API) gets its own Traefik route under its own FQDN, with TLS terminated by Traefik
* Phishing/landing-page server can either get its own FQDN, or you route it yourself in Traefik under one or more domains
* Campaigns, templates, landing pages and results live in a rootless Podman volume (SQLite), so they survive restarts and updates
* Records the real client IP behind the reverse proxy, and can show a contact address to recipients who report a simulated mail

A few things to know:

* For **authorised** testing only — running phishing campaigns against people without their permission is illegal in most jurisdictions. Test your own users, with sign-off.
* GoPhish doesn't send mail by itself: you create a Sending Profile pointing at an SMTP relay you're allowed to use, and you'll want SPF/DKIM/DMARC in order for the simulated mails to actually land.
* On first start GoPhish writes a temporary `admin` password to its log (the Settings page shows it) — log in and change it straight away.
* Heads up: upstream GoPhish hasn't tagged a release since v0.12.1 (2022), so this packages that version.

It's had a fair bit of testing here, but I'd love a second pair of eyes — if you give it a go, let me know how the phishing-host routing works out for you.

Docs: NethServer wiki (tebbiworld repository) · Source: [github.com/tebbiworld/ns8-gophish](https://github.com/tebbiworld/ns8-gophish)

Thanks!

*Category: App · Tags: ns8*

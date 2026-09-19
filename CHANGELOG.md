# Changelog

## 1.1.2 — 2026-09-19

Alignment with the NethServer module conventions (NethServer/agents skills).

### Fixed

- `restore-module` now passes every setting to `configure-module`: the Let's Encrypt choice of the original instance was lost on restore.

### Added

- Robot Framework tests (install, update from the previous release, backup and restore) run on real NS8 nodes through `stephdl/ns8-ci-actions`.

Secrets: nothing to move, this module stores no password in its environment.

## 1.1.1 — 2026-09-18

- Fix the update path: applying an update now restarts the container so it
  actually runs the new image. In 1.1.0 the update hook delegated the restart
  to configure-module, which only restarts on a configuration change, so after
  an update the module kept running the previous image until the next manual
  restart or reboot. The update hook now forces the restart.

## 1.1.0 — 2026-09-18

- **Fix admin login "Forbidden - referer invalid" behind the proxy.** GoPhish
  passes `trusted_origins` straight to gorilla/csrf, whose referer check
  compares the bare `Referer` host, so the value must be the host name
  (`gophish-admin.example.org`), not a URL with a scheme. The entrypoint now
  writes the bare admin host. The old `https://…` value only worked where the
  proxy made GoPhish see the request as plain HTTP (e.g. some cross-node
  setups), which skipped the check; a same-node HTTPS route triggered it and
  rejected every login.

- The **phishing host name is now optional**. Leave it empty and the module no
  longer creates a Traefik route for the phishing server; instead it publishes
  the phishing port on the node's WireGuard IP and shows the target
  `http://<wg-ip>:<phish-port>`. You then create one or more Traefik routes for
  it by hand, each with its own FQDN and Let's Encrypt certificate, so several
  landing-page domains can share the one phishing server. GoPhish tells the
  campaigns apart by the link (`rid`), not the host name. This also fits
  multi-node clusters, where a module not on the exposed node must be routed by
  hand anyway.
- Changing the phishing host name (or clearing it) **no longer restarts the
  container**: the phishing host is only a route matcher and never reaches the
  container. The container is restarted only when a value it actually reads
  changes (admin host, contact address, or the publish address).
- The admin server is unchanged: it keeps its required FQDN, its module-managed
  route and its `trusted_origins` CSRF setting.
- On update, an instance created before 1.1.0 has its phishing port re-published
  on the WireGuard IP and its managed route re-pointed automatically.

## 1.0.0 — 2026-09-17

- Initial release: GoPhish v0.12.1 built server-side from the official release
  ZIP into the module's own image (`gophish-app`); two Traefik routes (admin
  host → admin server 3333, phishing host → phishing server 80) with TLS
  terminated by Traefik and `use_tls=false` inside the container;
  `trusted_origins` set to the external admin URL; SQLite database and
  `config.json` in a persistent volume, (re)generated from the module
  parameters at every start; settings for admin host, phishing host and contact
  address; backup of settings and the data volume; restore; settings UI
  (EN/DE); automatic upstream-update releases from the GoPhish git tags.

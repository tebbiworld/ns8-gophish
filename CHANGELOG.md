# Changelog

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

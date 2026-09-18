# ns8-gophish

[NethServer 8](https://github.com/NethServer/ns8-core) module for
**[GoPhish](https://getgophish.com/)**, the open-source phishing-simulation
framework, for **authorised** security-awareness testing of your own users.

- Built by the module from the official GoPhish release (`build-images.sh`
  downloads the pinned `gophish-vX.Y.Z-linux-64bit.zip`); no third-party
  image from Docker Hub
- The **admin server** (web UI + REST API, container port 3333) always gets a
  module-managed Traefik route under its own FQDN
- The **phishing server** (landing pages, container port 80) can be routed two
  ways: give it an FQDN and the module makes its route, or leave the FQDN empty
  and route it yourself in Traefik under one or more FQDNs (see below)
- TLS terminated by Traefik; both servers run plain HTTP inside the container
  (`use_tls=false`), and `trusted_origins` is set to `https://<admin_host>` so
  the admin server's origin check passes behind the reverse proxy
- SQLite storage (`gophish.db`) and `config.json` in a rootless Podman volume,
  so campaigns and accounts survive restarts and updates
- Settings: admin host, optional phishing host, optional contact address

> Use GoPhish only against recipients you are authorised to test. Running
> phishing campaigns against people without permission is illegal in most
> jurisdictions.

## Install

Add the repository `https://raw.githubusercontent.com/tebbiworld/ns8-repo/main/ns8/updates/`
in Software Center → Repositories, then install *GoPhish*. Or from the leader
node:

    add-module ghcr.io/tebbiworld/gophish:latest 1

## Configure

Open the instance settings and set:

| Parameter | Meaning |
| --- | --- |
| Admin host name | FQDN of the admin UI / REST API (e.g. `gophish-admin.example.org`) |
| Phishing host name | Optional. FQDN serving the landing pages (e.g. `mail-check.example.org`); must differ from the admin host. Leave empty to route the phishing port yourself (see *Routing the phishing server yourself*) |
| Contact address | Optional, shown to recipients who report a simulated mail |
| Let's Encrypt | Issue TLS certificates for both host names |
| HTTP→HTTPS | Redirect plain HTTP to HTTPS |

The admin host must resolve to the node and is published through Traefik.
Use a neutral-looking phishing host name; keep the admin host private.

### Routing the phishing server yourself

Leave the phishing host name empty when you want to serve the landing pages
under several domains, or when the module runs on a node that is not the
Internet-facing one. The module then publishes the phishing port on the node's
WireGuard IP and the Settings page shows the target, e.g.
`http://10.5.5.1:20012`.

In cluster-admin open **Settings → HTTP routes → Create route** and set:

| Field | Value |
| --- | --- |
| Host | your landing-page FQDN (e.g. `promo-login.example.org`) |
| URL (backend target) | the target the module shows, e.g. `http://10.5.5.1:20012` |
| Request Let's Encrypt certificate | on |

Repeat for as many landing-page domains as you like. Same-node and cross-node both work: the
port is reachable from any node's Traefik over the trusted cluster mesh
(`10.5.5.0/24`), but never on the public interface. GoPhish tells the campaigns
apart by the `rid` in the link, not by the host name, so every domain you route
serves every campaign; you pick the domain per campaign in the sending URL.

Changing or clearing the phishing host name never restarts the container.

## First login

GoPhish writes a **temporary password for the user `admin`** to its log on the
first start (when the database is created). The Settings page shows it while it
is still the initial password. You can also read it from the node:

    runagent -m gophish1 podman logs gophish 2>&1 | grep -i "Please login with the username admin"

Log in at `https://<admin_host>/`, then change the password immediately under
*Account Settings*. After you change it the temporary password is gone (only a
hash is stored); if you lose access you must reset the database.

## Sending e-mail (SMTP)

GoPhish does not send mail on its own — you create a **Sending Profile** in the
admin UI (SMTP host, port, from address, credentials). For deliverability of
the simulated mails:

- point the Sending Profile at an SMTP relay you are allowed to use;
- publish an **SPF** record that authorises that relay for the from-domain, and
  sign with **DKIM** (and align **DMARC**), otherwise the simulated mails are
  likely to be rejected or land in spam — which distorts the test;
- use a from-domain and phishing host name that fit the scenario you are
  authorised to run.

## Captured client IP behind Traefik (verified)

The phishing server records the **real client IP**, not the Traefik IP. GoPhish
wraps the phishing handler in `handlers.ProxyHeaders` (gorilla), which rewrites
the request's remote address from the `X-Forwarded-For` header that Traefik
sets. Verified against the GoPhish v0.12.1 source (`controllers/phish.go`) and
by inspection of the request path.

Caveat: because `ProxyHeaders` trusts `X-Forwarded-For`, a recipient who
tampers with that header on their own request can influence the recorded IP.
For an internal awareness test behind Traefik this is not usually a concern,
but do not treat the recorded IP as forensic evidence.

## Backup and restore

The NS8 backup contains the module settings and the `gophish-data` volume
(`config.json` and the SQLite database with users, campaigns, templates,
landing pages and results). A restore recreates the instance, republishes both
Traefik routes on the target node and starts GoPhish on the restored volume.

## Updates

The module pins the GoPhish release in `build-images.sh`. A weekly GitHub
Action checks the GoPhish git tags and, when a newer stable release is at least
six weeks old, rebuilds `gophish-app` and publishes a new module version. Note
that upstream GoPhish has not tagged a release since v0.12.1 (September 2022).

## Development

    IMAGETAG=1.0.0 bash ./build-images.sh

`gophish/Containerfile` downloads and extracts the pinned release into a slim
Debian image; `gophish/entrypoint.sh` generates `config.json` in the data
volume from the module parameters at every start.

## License

Module: GPL-3.0-or-later. GoPhish is MIT-licensed, © the GoPhish authors; the
module builds the unmodified upstream release. The GoPhish logo is used to
identify the upstream project.

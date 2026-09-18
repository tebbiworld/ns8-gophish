#!/bin/sh
#
# Copyright (C) 2026 tebbi
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Generate config.json in the data volume from the module parameters (passed as
# environment variables by the systemd unit) and start GoPhish. Writing the
# config at every start keeps it in the persistent volume and always in sync
# with the settings, and it survives image updates.
#
#   admin_server  0.0.0.0:3333  use_tls=false   (TLS terminated by Traefik)
#   phish_server  0.0.0.0:80    use_tls=false   (TLS terminated by Traefik)
#   trusted_origins = [ <admin_host> ]  (bare host, no scheme: gorilla/csrf
#                     check accepts requests coming through the reverse proxy
#   db_name sqlite3, db_path <volume>/gophish.db, migrations under ./db (image)

set -e

data="${GOPHISH_DATA:-/var/lib/gophish}"
mkdir -p "$data"

admin_host="${GOPHISH_ADMIN_HOST:-}"
phish_host="${GOPHISH_PHISH_HOST:-}"
contact="${GOPHISH_CONTACT_ADDRESS:-}"

if [ -z "$admin_host" ]; then
    echo "GOPHISH_ADMIN_HOST is not set; refusing to start with an empty trusted origin" >&2
    exit 1
fi

jq -n \
    --arg dbpath "$data/gophish.db" \
    --arg contact "$contact" \
    --arg origin "${admin_host}" \
    '{
        admin_server: {
            listen_url: "0.0.0.0:3333",
            use_tls: false,
            cert_path: "gophish_admin.crt",
            key_path: "gophish_admin.key",
            trusted_origins: [$origin]
        },
        phish_server: {
            listen_url: "0.0.0.0:80",
            use_tls: false,
            cert_path: "example.crt",
            key_path: "example.key"
        },
        db_name: "sqlite3",
        db_path: $dbpath,
        migrations_prefix: "db/db_",
        contact_address: $contact,
        logging: { filename: "", level: "" }
    }' > "$data/config.json.tmp"
mv "$data/config.json.tmp" "$data/config.json"

echo "gophish ${GOPHISH_VERSION:-?} starting: admin 0.0.0.0:3333, phish 0.0.0.0:80, db $data/gophish.db, trusted origin ${admin_host}" >&2
# working directory stays /opt/gophish so migrations_prefix (db/db_), static/
# and templates/ resolve; the database and config live in the volume.
exec ./gophish --config "$data/config.json"

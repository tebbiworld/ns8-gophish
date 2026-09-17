#!/bin/bash

#
# Copyright (C) 2026 tebbi
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e

images=()
repobase="${REPOBASE:-ghcr.io/tebbiworld}"
reponame="gophish"

# GoPhish is built from the official upstream release ZIP (see gophish/Containerfile),
# not from any Docker Hub image. The pinned reference below is what the
# auto-release workflow bumps when a newer stable tag appears on GitHub.
gophish_ref="github.com/gophish/gophish:v0.12.1"
gophish_version="${gophish_ref##*:}"

# Runtime image, tagged with the module version like the module image itself;
# exposed to the unit as ${GOPHISH_APP_IMAGE} through org.nethserver.images.
app_image="${repobase}/gophish-app:${IMAGETAG:-latest}"

echo "Build the GoPhish ${gophish_version} application image..."
podman build --force-rm --build-arg "GOPHISH_VERSION=${gophish_version}" -t "${app_image}" -f gophish/Containerfile gophish/
podman tag "${app_image}" "${repobase}/gophish-app"
images+=("${repobase}/gophish-app")

runtime_images=(
    "${app_image}"
)

container=$(buildah from scratch)

if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-gophish; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-gophish -v "${PWD}:/usr/src:Z" docker.io/library/node:24.16.0-slim
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-gophish \
    sh -c "yarn install && yarn build"

buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui
# traefik@node:routeadm: the module publishes two HTTP routes (admin + phishing)
# through Traefik, which also terminates TLS. Two loopback ports are demanded
# from the core (tcp-ports-demand=2); no node firewall service is needed.
buildah config --entrypoint=/ \
    --label="org.nethserver.authorizations=traefik@node:routeadm" \
    --label="org.nethserver.tcp-ports-demand=2" \
    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.images=${runtime_images[*]}" \
    "${container}"
buildah commit "${container}" "${repobase}/${reponame}"

images+=("${repobase}/${reponame}")

if [[ -n "${CI}" ]]; then
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    printf "Publish the images with:\n\n"
    printf "  buildah push %s docker://%s\n" "${app_image,,}" "${app_image,,}"
    printf "  buildah push %s docker://%s:%s\n" "${repobase,,}/${reponame,,}" "${repobase,,}/${reponame,,}" "${IMAGETAG:-latest}"
    printf "\n"
fi

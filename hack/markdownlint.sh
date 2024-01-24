#!/bin/sh

set -eux

IS_CONTAINER="${IS_CONTAINER:-false}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

if [ "${IS_CONTAINER}" != "false" ]; then
    markdownlint-cli2 "**/*.md" "#node_modules"
else
    "${CONTAINER_RUNTIME}" run --rm \
        --env IS_CONTAINER=TRUE \
        --volume "${PWD}:/workdir:ro,z" \
        --entrypoint sh \
        --workdir /workdir \
        docker.io/pipelinecomponents/markdownlint-cli2:0.9.0@sha256:71370df6c967bae548b0bfd0ae313ddf44bfad87da76f88180eff55c6264098c \
        /workdir/hack/markdownlint.sh "$@"
fi

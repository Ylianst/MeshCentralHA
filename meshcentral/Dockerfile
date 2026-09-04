ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.19
FROM ${BUILD_FROM}

# Version of the meshcentral npm package to install.
ARG MESHCENTRAL_VERSION=1.1.21

ENV LANG=C.UTF-8

# MeshCentral is a Node.js application. The Home Assistant base image is
# Alpine-based, so we install Node.js, npm and the toolchain needed to
# compile any optional native dependencies.
RUN \
    apk add --no-cache \
        nodejs \
        npm \
        openssl \
        tzdata \
    && apk add --no-cache --virtual .build-deps \
        build-base \
        python3 \
    && npm install -g --omit=dev "meshcentral@${MESHCENTRAL_VERSION}" \
    && apk del --no-cache .build-deps \
    && rm -rf /root/.npm /tmp/*

# Copy root filesystem (startup script + config generator).
COPY rootfs /

RUN chmod a+x /run.sh

WORKDIR /data/meshcentral

LABEL \
    org.opencontainers.image.title="MeshCentral" \
    org.opencontainers.image.description="Open-source web-based remote computer management server." \
    org.opencontainers.image.source="https://github.com/Ylianst/MeshCentralHA" \
    org.opencontainers.image.licenses="Apache-2.0"

CMD [ "/run.sh" ]

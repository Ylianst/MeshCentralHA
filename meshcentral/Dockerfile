ARG BUILD_FROM
FROM ${BUILD_FROM}

# Version of the meshcentral npm package to install. Keep in sync with
# the "version" field in config.yaml.
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

CMD [ "/run.sh" ]

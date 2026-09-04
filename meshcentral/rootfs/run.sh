#!/usr/bin/env bashio
# ==============================================================================
# MeshCentral Home Assistant add-on startup script.
#
# 1. Installs Home Assistant's TLS certificate.
# 2. Generates MeshCentral's config.json from the add-on options.
# 3. Launches MeshCentral and watches the Home Assistant certificate,
#    restarting MeshCentral when it is renewed.
# ==============================================================================
set -e

DATA_PATH="/data/meshcentral"
mkdir -p "${DATA_PATH}"

# The Home Assistant certificate is always used, read from fixed /ssl filenames.
CERT_SRC="/ssl/fullchain.pem"
KEY_SRC="/ssl/privkey.pem"

# Copy Home Assistant's certificate into the filenames MeshCentral loads. The
# MeshCentral 'cert' name is derived from the certificate itself (see
# generate-config.js), so it always matches and MeshCentral serves this cert.
install_ha_cert() {
    if bashio::fs.file_exists "${CERT_SRC}" && bashio::fs.file_exists "${KEY_SRC}"; then
        cp "${CERT_SRC}" "${DATA_PATH}/webserver-cert-public.crt"
        cp "${KEY_SRC}" "${DATA_PATH}/webserver-cert-private.key"
        bashio::log.info "Installed Home Assistant certificate from ${CERT_SRC}."
    else
        bashio::log.warning "${CERT_SRC} or ${KEY_SRC} was not found in /ssl."
        bashio::log.warning "MeshCentral will fall back to its own self-signed certificate."
    fi
}

# Hash of the certificate files, used to detect renewals.
cert_signature() {
    if bashio::fs.file_exists "${CERT_SRC}"; then
        sha256sum "${CERT_SRC}" "${KEY_SRC}" 2>/dev/null | awk '{ print $1 }' | tr -d '\n'
    fi
}

install_ha_cert

# If the user dropped their own config.user.json in the data folder we honour it
# verbatim and skip generation. Otherwise we build config.json from the options.
if bashio::fs.file_exists "${DATA_PATH}/config.user.json"; then
    bashio::log.info "Found config.user.json, using it as-is (options ignored)."
    cp "${DATA_PATH}/config.user.json" "${DATA_PATH}/config.json"
else
    bashio::log.info "Generating config.json from add-on options..."
    node /usr/bin/generate-config.js
fi

# From here on we manage the MeshCentral child process ourselves so we can
# reload certificates, so disable automatic exit-on-error.
set +e

MESH_PID=""

start_mesh() {
    meshcentral --datapath "${DATA_PATH}" &
    MESH_PID=$!
    bashio::log.info "MeshCentral started (pid ${MESH_PID})."
}

stop_mesh() {
    if [ -n "${MESH_PID}" ] && kill -0 "${MESH_PID}" 2>/dev/null; then
        kill -TERM "${MESH_PID}" 2>/dev/null
        wait "${MESH_PID}" 2>/dev/null
    fi
}

# Forward container shutdown to MeshCentral for a clean stop.
on_term() {
    bashio::log.info "Shutting down MeshCentral..."
    stop_mesh
    exit 0
}
trap on_term SIGTERM SIGINT

start_mesh

bashio::log.info "Watching Home Assistant certificate for renewals."
LAST_SIG="$(cert_signature)"
CHECK_INTERVAL=3600

while true; do
    # If MeshCentral exited on its own, mirror its exit code.
    if ! kill -0 "${MESH_PID}" 2>/dev/null; then
        wait "${MESH_PID}"
        exit $?
    fi

    # Sleep in the background so an incoming SIGTERM interrupts it immediately.
    sleep "${CHECK_INTERVAL}" &
    wait $!

    NEW_SIG="$(cert_signature)"
    if [ -n "${NEW_SIG}" ] && [ "${NEW_SIG}" != "${LAST_SIG}" ]; then
        bashio::log.info "Home Assistant certificate changed, reloading MeshCentral..."
        install_ha_cert
        stop_mesh
        start_mesh
        LAST_SIG="${NEW_SIG}"
    fi
done

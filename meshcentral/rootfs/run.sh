#!/usr/bin/env bashio
# ==============================================================================
# MeshCentral Home Assistant add-on startup script.
#
# 1. Moves data to the persistent addon_config folder (survives uninstall).
# 2. Installs Home Assistant's TLS certificate.
# 3. Generates MeshCentral's config.json from the add-on options.
# 4. Launches MeshCentral and watches the Home Assistant certificate,
#    restarting MeshCentral when it is renewed.
# ==============================================================================
set -e

# Persistent storage. /config is the add-on's addon_config folder, which
# survives add-on updates AND uninstall/reinstall (unlike /data). MeshCentral
# data and automatic backups live in sibling folders there.
PERSIST_ROOT="/config"
DATA_PATH="${PERSIST_ROOT}/meshcentral-data"
BACKUP_PATH="${PERSIST_ROOT}/meshcentral-backups"
LEGACY_DATA_PATH="/data/meshcentral"

mkdir -p "${DATA_PATH}" "${BACKUP_PATH}"

# One-time migration from the old /data location. Copy the previous database,
# certificates and config over the first time we see an empty persistent folder.
if [ ! -f "${DATA_PATH}/meshcentral.db" ] \
    && [ ! -f "${DATA_PATH}/config.user.json" ] \
    && [ -d "${LEGACY_DATA_PATH}" ] \
    && [ -n "$(ls -A "${LEGACY_DATA_PATH}" 2>/dev/null)" ]; then
    bashio::log.info "Migrating existing data from ${LEGACY_DATA_PATH} to ${DATA_PATH}..."
    cp -a "${LEGACY_DATA_PATH}/." "${DATA_PATH}/" 2>/dev/null || true
fi

# Expose the resolved paths to the config generator.
export MESH_DATA_PATH="${DATA_PATH}"
export MESH_BACKUP_PATH="${BACKUP_PATH}"

# The Home Assistant certificate is used only when it is an RSA certificate.
CERT_SRC="/ssl/fullchain.pem"
KEY_SRC="/ssl/privkey.pem"

# Report the public-key type of a PEM certificate ("rsa", "ec", ...). Uses
# Node's OpenSSL-backed parser, which (unlike MeshCentral's node-forge) reads
# every key type.
cert_key_type() {
    node -e '
        const fs = require("fs");
        try {
            const c = new (require("crypto").X509Certificate)(fs.readFileSync(process.argv[1]));
            process.stdout.write((c.publicKey.asymmetricKeyType || "").toLowerCase());
        } catch (e) { process.stdout.write(""); }
    ' "$1" 2>/dev/null
}

# MeshCentral parses the web-server certificate with node-forge, which only
# supports RSA. So we inject Home Assistant's certificate only when it is RSA;
# otherwise MeshCentral falls back to its own self-signed certificate. The
# 'cert' name is derived from the certificate (see generate-config.js) so it
# always matches when we do install it.
install_ha_cert() {
    if ! ( bashio::fs.file_exists "${CERT_SRC}" && bashio::fs.file_exists "${KEY_SRC}" ); then
        bashio::log.warning "${CERT_SRC} or ${KEY_SRC} was not found in /ssl."
        bashio::log.warning "MeshCentral will use its own self-signed certificate."
        return
    fi

    if [ "$(cert_key_type "${CERT_SRC}")" = "rsa" ]; then
        cp "${CERT_SRC}" "${DATA_PATH}/webserver-cert-public.crt"
        cp "${KEY_SRC}" "${DATA_PATH}/webserver-cert-private.key"
        bashio::log.info "Installed Home Assistant RSA certificate from ${CERT_SRC}."
        return
    fi

    bashio::log.warning "Home Assistant certificate is not RSA (MeshCentral cannot use it); using MeshCentral's own self-signed certificate."
    # Remove only a previously injected non-RSA cert. MeshCentral's own cert is
    # RSA, so this never deletes it (which would change the cert hash and break
    # enrolled agents).
    if [ -f "${DATA_PATH}/webserver-cert-public.crt" ] \
        && [ "$(cert_key_type "${DATA_PATH}/webserver-cert-public.crt")" != "rsa" ]; then
        rm -f "${DATA_PATH}/webserver-cert-public.crt" "${DATA_PATH}/webserver-cert-private.key"
        bashio::log.info "Removed a previously injected non-RSA certificate so MeshCentral can self-sign."
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
MESH_LOG="${DATA_PATH}/meshcentral.log"

start_mesh() {
    # Run the locally-installed MeshCentral package directly with node. The
    # global `meshcentral` bin shim fails silently on Alpine (module path
    # issues), so we invoke node_modules/meshcentral. Tee its output to both
    # the add-on log (live) and a file so startup messages/errors are visible.
    node /opt/meshcentral/node_modules/meshcentral --datapath "${DATA_PATH}" > >(tee "${MESH_LOG}") 2>&1 &
    MESH_PID=$!
    bashio::log.info "MeshCentral started (pid ${MESH_PID})."
}

# Poll the container HTTPS port until MeshCentral is listening (first-run
# certificate generation can take a while). If it never comes up, dump the
# config, data directory and error log so the failure is visible.
diagnose_listen() {
    local waited=0
    local interval=5
    local max=120
    while [ "${waited}" -lt "${max}" ]; do
        if node -e '
            const net = require("net");
            const s = net.connect(443, "127.0.0.1");
            s.setTimeout(3000);
            s.on("connect", () => { s.end(); process.exit(0); });
            s.on("timeout", () => process.exit(1));
            s.on("error", () => process.exit(1));
        ' 2>/dev/null; then
            bashio::log.info "DIAG: MeshCentral is listening on container port 443 (after ${waited}s)."
            return 0
        fi
        sleep "${interval}"
        waited=$((waited + interval))
    done
    bashio::log.warning "DIAG: MeshCentral is NOT listening on container port 443 after ${max}s."
    bashio::log.info "DIAG: generated config.json:"
    cat "${DATA_PATH}/config.json" 2>&1 || true
    bashio::log.info "DIAG: data directory:"
    ls -la "${DATA_PATH}" 2>&1 || true
    bashio::log.info "DIAG: MeshCentral output:"
    cat "${MESH_LOG}" 2>&1 || true
    if [ -f "${DATA_PATH}/mesherrors.txt" ]; then
        bashio::log.info "DIAG: mesherrors.txt:"
        tail -n 60 "${DATA_PATH}/mesherrors.txt" 2>&1 || true
    fi
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
diagnose_listen &

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

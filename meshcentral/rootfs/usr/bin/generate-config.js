#!/usr/bin/env node
/*
 * Translates the Home Assistant add-on options (/data/options.json) into a
 * MeshCentral configuration file (/data/meshcentral/config.json).
 *
 * A random sessionKey is generated and persisted on first run when the user
 * does not supply one, so that existing sessions survive add-on restarts.
 */
'use strict';

const fs = require('fs');
const crypto = require('crypto');

const OPTIONS_PATH = '/data/options.json';
const DATA_PATH = process.env.MESH_DATA_PATH || '/data/meshcentral';
const BACKUP_PATH = process.env.MESH_BACKUP_PATH || `${DATA_PATH}/backups`;
const CONFIG_PATH = `${DATA_PATH}/config.json`;
const SESSION_KEY_PATH = `${DATA_PATH}/.session_key`;
const CERT_PATH = '/ssl/fullchain.pem';

function readOptions() {
    try {
        return JSON.parse(fs.readFileSync(OPTIONS_PATH, 'utf8'));
    } catch (err) {
        console.error(`Unable to read ${OPTIONS_PATH}: ${err.message}`);
        return {};
    }
}

// Derive the certificate's hostname (first DNS SAN, else subject CN) from the
// Home Assistant certificate so MeshCentral's 'cert' name matches and it serves
// that certificate instead of regenerating a self-signed one.
function certHostname() {
    try {
        const x509 = new crypto.X509Certificate(fs.readFileSync(CERT_PATH));
        const san = x509.subjectAltName || '';
        const dns = san
            .split(',')
            .map((entry) => entry.trim())
            .find((entry) => entry.startsWith('DNS:'));
        if (dns) { return dns.slice(4).trim(); }
        const cn = /CN=([^,\n]+)/.exec(x509.subject || '');
        if (cn) { return cn[1].trim(); }
    } catch (err) {
        console.error(`Unable to read certificate hostname from ${CERT_PATH}: ${err.message}`);
    }
    return '';
}

// Return the configured session key, or a persisted/generated random one.
function resolveSessionKey(options) {
    if (options.session_key && options.session_key.trim() !== '') {
        return options.session_key.trim();
    }
    try {
        if (fs.existsSync(SESSION_KEY_PATH)) {
            const existing = fs.readFileSync(SESSION_KEY_PATH, 'utf8').trim();
            if (existing !== '') { return existing; }
        }
    } catch (err) {
        console.error(`Unable to read persisted session key: ${err.message}`);
    }
    const generated = crypto.randomBytes(32).toString('hex');
    try {
        fs.writeFileSync(SESSION_KEY_PATH, generated, { mode: 0o600 });
    } catch (err) {
        console.error(`Unable to persist session key: ${err.message}`);
    }
    return generated;
}

function buildConfig(options) {
    const settings = {
        // MeshCentral always listens on the standard ports inside the
        // container; the host mapping is controlled from the add-on UI.
        port: 443,
        redirPort: 80,
        sessionKey: resolveSessionKey(options),
        // WebRTC lets browser and agent talk peer-to-peer, cutting server relay
        // load. It falls back to the relay automatically when unavailable.
        webrtc: true,
        // Automatic daily backups kept for 10 days, stored in the persistent
        // addon_config folder so they survive updates and reinstalls.
        autoBackup: {
            backupIntervalHours: 24,
            keepLastDaysBackup: 10,
            backupPath: BACKUP_PATH,
        },
    };

    // The container's 443/80 are mapped to different host ports (default
    // 8443/8080) so they don't clash with Home Assistant on 80/443. aliasPort
    // tells MeshCentral which external port agents/browsers actually use, so
    // generated agent installers and links point at the right port.
    const httpsPort = parseInt(options.external_https_port, 10) || 8443;
    if (httpsPort !== 443) { settings.aliasPort = httpsPort; }

    const host = certHostname();
    if (host) { settings.cert = host; }

    const domain = {
        title: options.server_title || 'MeshCentral',
        newAccounts: options.allow_new_accounts !== false,
    };

    const config = {
        settings,
        domains: { '': domain },
    };

    return config;
}

function main() {
    fs.mkdirSync(DATA_PATH, { recursive: true });
    const options = readOptions();
    const config = buildConfig(options);
    fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
    console.log(`Wrote ${CONFIG_PATH}`);
}

main();

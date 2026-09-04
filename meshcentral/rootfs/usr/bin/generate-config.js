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
const DATA_PATH = '/data/meshcentral';
const CONFIG_PATH = `${DATA_PATH}/config.json`;
const SESSION_KEY_PATH = `${DATA_PATH}/.session_key`;

function readOptions() {
    try {
        return JSON.parse(fs.readFileSync(OPTIONS_PATH, 'utf8'));
    } catch (err) {
        console.error(`Unable to read ${OPTIONS_PATH}: ${err.message}`);
        return {};
    }
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

// Split a comma/whitespace separated string into a trimmed, non-empty array.
function splitList(value) {
    if (!value) { return []; }
    return value
        .split(/[,\s]+/)
        .map((item) => item.trim())
        .filter((item) => item !== '');
}

function buildConfig(options) {
    const settings = {
        // MeshCentral always listens on the standard ports inside the
        // container; the host mapping is controlled from the add-on UI.
        port: 443,
        redirPort: 80,
        sessionKey: resolveSessionKey(options),
    };

    // The container's 443/80 are mapped to different host ports (default
    // 8443/8080) so they don't clash with Home Assistant on 80/443. aliasPort
    // tells MeshCentral which external port agents/browsers actually use, so
    // generated agent installers and links point at the right port.
    const httpsPort = parseInt(options.external_https_port, 10) || 8443;
    if (httpsPort !== 443) { settings.aliasPort = httpsPort; }

    if (options.hostname && options.hostname.trim() !== '') {
        settings.cert = options.hostname.trim();
    }
    if (options.wan_only) { settings.WANonly = true; }
    if (options.lan_only) { settings.LANonly = true; }
    if (options.tls_offload) { settings.tlsOffload = true; }
    if (options.mongodb_url && options.mongodb_url.trim() !== '') {
        settings.mongoDb = options.mongodb_url.trim();
    }

    // Allow the MeshCentral UI to be embedded in a Home Assistant iframe panel.
    // Restricting to specific origins is preferred over blanket framing.
    const framingOrigins = splitList(options.allowed_framing_origins);
    if (framingOrigins.length > 0) {
        settings.allowedFramingOrigins = framingOrigins;
        settings.AllowFraming = true;
    } else if (options.allow_framing) {
        settings.AllowFraming = true;
    }
    // Cross-site iframe embedding requires SameSite=None cookies (over HTTPS).
    if (settings.AllowFraming) { settings.cookieSameSite = 'None'; }

    const domain = {
        title: options.server_title || 'MeshCentral',
        newAccounts: options.allow_new_accounts !== false,
    };

    const config = {
        settings,
        domains: { '': domain },
    };

    const leNames = splitList(options.lets_encrypt_names);
    if (options.lets_encrypt_email && options.lets_encrypt_email.trim() !== '' && leNames.length > 0) {
        config.letsencrypt = {
            email: options.lets_encrypt_email.trim(),
            names: leNames.join(','),
            production: options.lets_encrypt_production === true,
        };
    }

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

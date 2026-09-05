# Changelog

## 1.1.21-12

- **Fixes a crash loop with EC/ECDSA Home Assistant certificates**
  (`Cannot read public key. OID is not RSA`). MeshCentral's certificate library
  only supports RSA, so the Home Assistant certificate is now injected only when
  it is RSA. For EC (elliptic-curve) certificates, MeshCentral uses its own
  self-signed certificate instead of crashing. A previously injected non-RSA
  certificate is cleaned up safely without touching MeshCentral's own cert.

## 1.1.21-11

- **Fixes MeshCentral never starting** (no output, no database or certificates
  generated). MeshCentral is now installed locally in `/opt/meshcentral` and
  launched with `node /opt/meshcentral/node_modules/meshcentral` instead of the
  global `meshcentral` bin, which fails silently on Alpine due to module-path
  resolution issues.

## 1.1.21-10

- MeshCentral's own console output is now streamed live into the add-on log, so
  startup progress and errors are visible.
- The startup diagnostic now polls the HTTPS port for up to two minutes (first
  run generates certificates and can take a while) instead of checking once
  after 15 seconds, and only dumps diagnostics if the server never comes up.

## 1.1.21-9

- Data now lives in the persistent **addon_config** folder
  (`/addon_configs/<slug>_meshcentral`), so it survives uninstall/reinstall as
  well as updates. Existing `/data/meshcentral` installs are migrated
  automatically on first start.
- Automatic server backups are always on (every 24 hours, last 10 days kept),
  stored alongside the data in the persistent folder — no configuration needed.
- WebRTC is enabled for peer-to-peer sessions, reducing server relay load.

## 1.1.21-8

- Expanded startup diagnostics: capture MeshCentral's own output to a log file
  and dump the generated config, data directory listing, and error log so a
  non-listening server can be diagnosed.

## 1.1.21-7

- Surface MeshCentral's own output in the add-on log and add a startup diagnostic
  that reports whether MeshCentral is listening on container port 443 (and shows
  recent MeshCentral errors), to help debug connectivity.

## 1.1.21-6

- Reverted the automatic port detection. Reading the Network mapping needs the
  Supervisor API, which is refused (`forbidden`) on some installs and caused a
  restart loop. The advertised HTTPS port is set with the `external_https_port`
  option again (default `8443`); no Supervisor API access is used.

## 1.1.21-5

- Reading the external port from the Network mapping now requires `hassio_api`
  and never crashes the add-on: if the Supervisor API is unavailable, it falls
  back to the default advertised port (`8443`) instead of restart-looping.

## 1.1.21-4

- Removed the `external_https_port` / `external_http_port` options. The external
  port is now read automatically from the add-on's **Network** port mapping, so
  ports are configured in one place only.

## 1.1.21-3

- Removed the `watch_certificate` option; certificate renewals are always
  watched.
- Removed the `wan_only` and `lan_only` options (always off).
- Removed the `mongodb_url` and `session_key` options. MeshCentral uses its
  built-in NeDB database and an auto-generated, persisted session key.

## 1.1.21-2

- Build the add-on locally from the Dockerfile (removed the prebuilt `image:`
  reference).
- Always serve Home Assistant's certificate from `/ssl` (`fullchain.pem` /
  `privkey.pem`); the hostname is detected automatically from the certificate.
- Removed the `hostname`, `use_ha_certificate`, `cert_file`, and `key_file`
  options (now automatic).
- Removed the Let's Encrypt options (`lets_encrypt_email`, `lets_encrypt_names`,
  `lets_encrypt_production`).
- Removed `tls_offload` and the iframe framing options (`allow_framing`,
  `allowed_framing_origins`).
- Moved build settings into the Dockerfile and removed the deprecated
  `build.yaml`.

## 1.1.21

- Initial release of the MeshCentral Home Assistant add-on.
- Installs the `meshcentral` npm package on a multi-arch Alpine base image.
- First-class add-on options mapped to MeshCentral `config.json`.
- Configurable external HTTPS/HTTP ports (default `8443`/`8080`) advertised to
  agents via MeshCentral's `aliasPort`.
- Optional `use_ha_certificate` to serve Home Assistant's TLS certificate from
  the `/ssl` share, with automatic reload on renewal (`watch_certificate`).
- Optional `allow_framing` / `allowed_framing_origins` to embed the MeshCentral
  UI in a Home Assistant iframe panel.
- Optional `config.user.json` override for full custom configuration.
- Persistent data stored under `/data/meshcentral`.

# MeshCentral

MeshCentral is a free, open-source, web-based remote computer management server.
Once running, install a MeshCentral agent on any computer and manage it remotely
(remote desktop, terminal, file transfer, wake-on-LAN, and more).

## Installation

1. Add this repository to Home Assistant (see the repository README).
2. Install the **MeshCentral** add-on.
3. Configure the options below.
4. Start the add-on and open the Web UI.

## Configuration

| Option                    | Description                                                                                          |
| ------------------------- | ---------------------------------------------------------------------------------------------------- |
| `server_title`            | Title shown on the MeshCentral login page.                                                           |
| `external_https_port`     | The **host** HTTPS port clients/agents connect to (default `8443`). Must match the host port mapped to container `443/tcp` in the **Network** tab. |
| `external_http_port`      | The **host** HTTP port used for redirects (default `8080`). Must match the host port mapped to container `80/tcp`. |
| `allow_new_accounts`      | Allow visitors to self-register new accounts. Turn off after creating your admin account.            |
| `watch_certificate`       | Watch the Home Assistant certificate and automatically reload MeshCentral when it is renewed.         |
| `wan_only`                | Run in WAN-only mode (server reached over the internet, no local network discovery).                 |
| `lan_only`                | Run in LAN-only mode (local network only, no fixed hostname required).                               |
| `mongodb_url`             | Optional MongoDB connection string. Leave empty to use the built-in NeDB database.                   |
| `session_key`             | Fixed session encryption key. Leave empty to auto-generate and persist one.                          |
| `log_to_file`             | Write MeshCentral logs to the data folder in addition to the add-on log.                             |

### Advanced: full custom configuration

If you need options that are not exposed above, place a complete MeshCentral
config file at:

```
/addon_configs/<slug>_meshcentral/config.user.json
```

or inside the add-on data folder as `meshcentral/config.user.json`. When present,
this file is used verbatim and the options above are ignored. See the
[MeshCentral config schema](https://github.com/Ylianst/MeshCentral/blob/master/meshcentral-config-schema.json).

## Ports

| Container port | Default host port | Purpose                                      |
| -------------- | ----------------- | -------------------------------------------- |
| `443/tcp`      | `8443`            | HTTPS web UI and agent connections.          |
| `80/tcp`       | `8080`            | HTTP redirect.                               |

MeshCentral always binds `443` and `80` **inside** the container. Because Home
Assistant itself commonly uses `80`/`443`, the add-on maps them to different
**host** ports by default (`8443` and `8080`) so there is no conflict.

Two things must agree:

1. The **host** ports mapped to `443/tcp` and `80/tcp` in the add-on **Network**
   tab.
2. The `external_https_port` / `external_http_port` options.

They default to `8443` / `8080`. If you change one, change the other to match —
otherwise agents receive the wrong port in their generated installers and cannot
connect. Internally MeshCentral still listens on `443`/`80`; `external_https_port`
is applied as MeshCentral's `aliasPort` so the advertised URLs are correct.

## Home Assistant certificate

The add-on **always** serves Home Assistant's own TLS certificate (for example a
Let's Encrypt certificate managed by the HA *Let's Encrypt* or *NGINX Home
Assistant SSL proxy* add-ons). There is nothing to configure.

How it works:

- The add-on mounts Home Assistant's `/ssl` share (read-only).
- On each start it copies `fullchain.pem` and `privkey.pem` from `/ssl` into
  MeshCentral's data folder as `webserver-cert-public.crt` /
  `webserver-cert-private.key`.
- The hostname is read **automatically** from the certificate (its first DNS SAN,
  or the subject common name) and given to MeshCentral, so the certificate always
  matches and is served rather than being replaced by a self-signed one.
- MeshCentral then serves that certificate on its own port.

Notes:

- Certificate **renewals are detected automatically**. When `watch_certificate`
  is on (the default), the add-on watches the files in `/ssl` and restarts
  MeshCentral so it reloads the new certificate. Set `watch_certificate: false`
  to require a manual restart instead.
- This shares the *certificate*, not the port. MeshCentral still runs on its own
  port; agents connect there directly. It does not place MeshCentral under a
  Home Assistant sub-path.
- If `/ssl/fullchain.pem` or `/ssl/privkey.pem` is missing, MeshCentral falls
  back to its own self-signed certificate and logs a warning.

## Data & backups

All persistent data (database, certificates, generated `config.json`) lives in
the add-on's `/data/meshcentral` folder and survives restarts and updates.
Back it up as part of your normal Home Assistant snapshots.

## Support

Issues with the add-on packaging: open an issue on the
[MeshCentralHA](https://github.com/Ylianst/MeshCentralHA)
repository. General MeshCentral questions: see the
[MeshCentral repository](https://github.com/Ylianst/MeshCentral).

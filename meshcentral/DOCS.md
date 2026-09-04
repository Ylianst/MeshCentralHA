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
| `hostname`                | The DNS name (or IP) clients use to reach the server. Used as the TLS certificate common name.       |
| `external_https_port`     | The **host** HTTPS port clients/agents connect to (default `8443`). Must match the host port mapped to container `443/tcp` in the **Network** tab. |
| `external_http_port`      | The **host** HTTP port used for redirects / ACME (default `8080`). Must match the host port mapped to container `80/tcp`. |
| `allow_new_accounts`      | Allow visitors to self-register new accounts. Turn off after creating your admin account.            |
| `tls_offload`             | Enable when running behind a reverse proxy that terminates TLS (e.g. NGINX, Traefik, Cloudflare).    |
| `use_ha_certificate`      | Serve Home Assistant's own TLS certificate (e.g. its Let's Encrypt cert) instead of a self-signed one. Reads the files from the `/ssl` share. |
| `cert_file`               | Certificate (full chain) filename inside `/ssl`. Default `fullchain.pem`. Used only when `use_ha_certificate` is on. |
| `key_file`                | Private key filename inside `/ssl`. Default `privkey.pem`. Used only when `use_ha_certificate` is on. |
| `watch_certificate`       | Watch the certificate and automatically reload MeshCentral when Home Assistant renews it. Only applies when `use_ha_certificate` is on. |
| `allow_framing`           | Allow the MeshCentral UI to be embedded in an iframe (e.g. a Home Assistant panel). Prefer `allowed_framing_origins` to restrict this. |
| `allowed_framing_origins` | Comma-separated list of origins allowed to embed MeshCentral, e.g. `https://homeassistant.local:8123`. Implies `allow_framing`. |
| `wan_only`                | Run in WAN-only mode (server reached over the internet, no local network discovery).                 |
| `lan_only`                | Run in LAN-only mode (local network only, no fixed hostname required).                               |
| `lets_encrypt_email`      | Email for Let's Encrypt registration. Requires `lets_encrypt_names` and public ports 80/443.         |
| `lets_encrypt_names`      | Comma-separated DNS names to request certificates for.                                               |
| `lets_encrypt_production` | Use the Let's Encrypt production CA. Leave off first to test against the staging CA.                 |
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
| `80/tcp`       | `8080`            | HTTP redirect and Let's Encrypt validation.  |

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

If you use Let's Encrypt, the host ports must be `443` and `80` and be reachable
from the internet — set both the Network mapping and the `external_*` options to
`443`/`80` in that case.

## Sharing Home Assistant's certificate

Enable `use_ha_certificate` to have MeshCentral present the same TLS certificate
as Home Assistant (for example a Let's Encrypt certificate managed by the HA
*Let's Encrypt* or *NGINX Home Assistant SSL proxy* add-ons).

How it works:

- The add-on mounts Home Assistant's `/ssl` share (read-only).
- On each start it copies `cert_file` (default `fullchain.pem`) and `key_file`
  (default `privkey.pem`) from `/ssl` into MeshCentral's data folder as
  `webserver-cert-public.crt` / `webserver-cert-private.key`.
- MeshCentral then serves that certificate on its own port.

Notes:

- **You must set `hostname` to the exact domain the certificate is issued for**
  (its common name / SAN). MeshCentral compares the configured name against the
  certificate and, if they do not match, ignores the supplied certificate and
  regenerates its own self-signed one (overwriting the copied files).
- Certificate **renewals are detected automatically**. When `watch_certificate`
  is on (the default), the add-on watches the files in `/ssl` and restarts
  MeshCentral so it reloads the new certificate. Set `watch_certificate: false`
  to require a manual restart instead.
- This shares the *certificate*, not the port. MeshCentral still runs on its own
  port; agents connect there directly. It does not place MeshCentral under a
  Home Assistant sub-path.
- If the files are missing, MeshCentral falls back to its own self-signed
  certificate and logs a warning.
- Do not combine this with the Let's Encrypt options below; use one or the other.

## Embedding the UI in Home Assistant

You can show the MeshCentral UI as a page inside Home Assistant using an iframe
panel in the sidebar.

> Home Assistant **Ingress** is *not* supported. Ingress serves add-ons under a
> dynamic per-session path, and MeshCentral has no awareness of that path, so
> its links and websockets would break. The iframe panel below is the supported
> way to embed the UI. (Managed agents always connect to the MeshCentral port
> directly regardless of how the UI is displayed.)

Steps:

1. Strongly recommended: enable `use_ha_certificate` and set `hostname` so the
   iframe loads over the same trusted certificate as Home Assistant (a
   self-signed certificate is blocked or warned about inside an iframe).
2. Allow Home Assistant to frame MeshCentral by setting `allowed_framing_origins`
   to your Home Assistant URL, for example:

   ```yaml
   allowed_framing_origins: "https://homeassistant.local:8123"
   ```

   (Or set `allow_framing: true` to allow any origin — less secure.) The add-on
   automatically sets the MeshCentral session cookie to `SameSite=None` so login
   works inside the cross-origin iframe.
3. Add an iframe panel to Home Assistant's `configuration.yaml` (this part is
   done in Home Assistant, not the add-on) and restart Home Assistant:

   ```yaml
   panel_iframe:
     meshcentral:
       title: "MeshCentral"
       icon: mdi:remote-desktop
       url: "https://your-server:8443/"
       require_admin: true
   ```

MeshCentral now appears in the Home Assistant sidebar.

## Data & backups

All persistent data (database, certificates, generated `config.json`) lives in
the add-on's `/data/meshcentral` folder and survives restarts and updates.
Back it up as part of your normal Home Assistant snapshots.

## Support

Issues with the add-on packaging: open an issue on the
[MeshCentralHA](https://github.com/Ylianst/MeshCentralHA)
repository. General MeshCentral questions: see the
[MeshCentral repository](https://github.com/Ylianst/MeshCentral).

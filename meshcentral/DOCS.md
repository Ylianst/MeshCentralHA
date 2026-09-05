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
| `external_https_port`     | The **host** HTTPS port agents connect to (default `8443`). Set it to the same value as the host port mapped to container `443/tcp` in the **Network** tab. |
| `allow_new_accounts`      | Allow visitors to self-register new accounts. Turn off after creating your admin account.            |
| `log_to_file`             | Write MeshCentral logs to the data folder in addition to the add-on log.                             |

### Advanced: full custom configuration

If you need options that are not exposed above, place a complete MeshCentral
config file at:

```
/addon_configs/<slug>_meshcentral/meshcentral-data/config.user.json
```

When present, this file is used verbatim and the options above are ignored. See
the
[MeshCentral config schema](https://github.com/Ylianst/MeshCentral/blob/master/meshcentral-config-schema.json).

## Ports

| Container port | Default host port | Purpose                                      |
| -------------- | ----------------- | -------------------------------------------- |
| `443/tcp`      | `8443`            | HTTPS web UI and agent connections.          |
| `80/tcp`       | `8080`            | HTTP redirect.                               |

MeshCentral always binds `443` and `80` **inside** the container. Because Home
Assistant itself commonly uses `80`/`443`, the add-on maps them to different
**host** ports by default (`8443` and `8080`) so there is no conflict.

Set the **host** ports in the add-on **Network** tab. MeshCentral still listens
on `443`/`80` internally. If you change the host port mapped to `443/tcp`, set
`external_https_port` to the same value so MeshCentral advertises the correct
port to agents (via its `aliasPort`); otherwise generated installers point at the
wrong port and agents cannot connect.

## Home Assistant certificate

If Home Assistant's own TLS certificate is an **RSA** certificate, the add-on
serves it automatically (for example an RSA Let's Encrypt certificate from the
HA *Let's Encrypt* or *NGINX Home Assistant SSL proxy* add-ons). There is
nothing to configure.

> **EC/ECDSA certificates:** MeshCentral's certificate library only supports
> RSA, so if your Home Assistant certificate uses an elliptic-curve (EC) key,
> the add-on cannot use it. In that case MeshCentral serves its **own
> self-signed certificate** instead — your browser will show a one-time
> certificate warning (this is normal and safe on your local network; agents
> trust the server by its certificate hash, not the CA).

How it works when the HA certificate is RSA:

- The add-on mounts Home Assistant's `/ssl` share (read-only).
- On each start it copies `fullchain.pem` and `privkey.pem` from `/ssl` into
  MeshCentral's data folder as `webserver-cert-public.crt` /
  `webserver-cert-private.key`.
- The hostname is read **automatically** from the certificate (its first DNS SAN,
  or the subject common name) and given to MeshCentral, so the certificate always
  matches and is served rather than being replaced by a self-signed one.
- MeshCentral then serves that certificate on its own port.

Notes:

- Certificate **renewals are detected automatically**. The add-on watches the
  files in `/ssl` and restarts MeshCentral so it reloads the new certificate.
- This shares the *certificate*, not the port. MeshCentral still runs on its own
  port; agents connect there directly. It does not place MeshCentral under a
  Home Assistant sub-path.
- If `/ssl/fullchain.pem` or `/ssl/privkey.pem` is missing (or is not RSA),
  MeshCentral falls back to its own self-signed certificate.

## Data & backups

All persistent data (database, certificates, generated `config.json`) lives in
the add-on's **config** folder, which survives restarts, updates **and even
uninstall/reinstall**. On the host it is at `/addon_configs/<slug>_meshcentral`
(also reachable through the *Samba*/`addon_configs` share) and is included in
Home Assistant's standard backups.

| Folder                 | Contents                                        |
| ---------------------- | ----------------------------------------------- |
| `meshcentral-data/`    | Database, certificates and generated `config.json`. |
| `meshcentral-backups/` | Automatic server backups.                       |

The add-on takes an **automatic backup every 24 hours** and keeps the last
**10 days** — no configuration needed. Existing installs are migrated
automatically: on first start after updating, anything found in the old
`/data/meshcentral` location is copied over.

## Support

Issues with the add-on packaging: open an issue on the
[MeshCentralHA](https://github.com/Ylianst/MeshCentralHA)
repository. General MeshCentral questions: see the
[MeshCentral repository](https://github.com/Ylianst/MeshCentral).

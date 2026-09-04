# Changelog

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

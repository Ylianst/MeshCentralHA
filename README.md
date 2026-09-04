# MeshCentralHA

[MeshCentral](https://meshcentral.com) is a full open-source web-based remote
computer management server. This repository packages MeshCentral as a
[Home Assistant](https://www.home-assistant.io/) add-on so you can run it
directly on your Home Assistant host.

## Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** menu (top-right) → **Repositories**.
3. Add this repository URL:

   ```
   https://github.com/Ylianst/MeshCentralHA
   ```

4. The **MeshCentral** add-on now appears in the store. Click it and press
   **Install**.
5. Open the **Configuration** tab, set your options (see
   [the add-on docs](meshcentral/DOCS.md)), then **Start** the add-on.

## What's in this repository

| Path                       | Purpose                                            |
| -------------------------- | -------------------------------------------------- |
| `repository.yaml`          | Add-on repository metadata read by the Supervisor. |
| `meshcentral/`             | The MeshCentral add-on itself.                      |
| `meshcentral/config.yaml`  | Add-on manifest and user-configurable options.      |
| `meshcentral/Dockerfile`   | Container build that installs the `meshcentral` npm package. |
| `meshcentral/DOCS.md`      | End-user documentation shown in the add-on UI.      |

## Ports

MeshCentral is served directly on the host (no Home Assistant Ingress):

| Container port | Default | Purpose                                        |
| -------------- | ------- | ---------------------------------------------- |
| `443/tcp`      | `8443`  | HTTPS web UI and agent connections.            |
| `80/tcp`       | `8080`  | HTTP redirect and Let's Encrypt validation.    |

You can remap the host ports from the add-on **Network** tab.

## License

MeshCentral is licensed under the Apache-2.0 license. See the
[MeshCentral repository](https://github.com/Ylianst/MeshCentral) for details.

# MeshCentralHA

[MeshCentral](https://meshcentral.com) is a full open-source web-based remote
computer management server. This repository packages MeshCentral as a
[Home Assistant](https://www.home-assistant.io/) app so you can run it
directly on your Home Assistant host.

> **Note:** Recent versions of Home Assistant renamed **Add-ons** to **Apps**
> (an add-on is now called an app). If your Home Assistant still shows
> **Add-ons**, use that menu instead — the steps are otherwise the same.

## Installation

1. In Home Assistant, go to **Settings → Apps** and select **Install app**
   to open the app store.
2. In the top-right corner, select the **⋮** menu → **Repositories**.
3. Add this repository URL, then select **Add**:

   ```
   https://github.com/Ylianst/MeshCentralHA
   ```

4. Close the dialog. The **MeshCentral** app now appears in the store. Select
   it and press **Install**.
5. Open the **Configuration** tab, set your options (see
   [the app docs](meshcentral/DOCS.md)), then **Start** the app.

## What's in this repository

| Path                       | Purpose                                            |
| -------------------------- | -------------------------------------------------- |
| `repository.yaml`          | App (add-on) repository metadata read by the Supervisor. |
| `meshcentral/`             | The MeshCentral app itself.                         |
| `meshcentral/config.yaml`  | App manifest and user-configurable options.         |
| `meshcentral/Dockerfile`   | Container build that installs the `meshcentral` npm package. |
| `meshcentral/DOCS.md`      | End-user documentation shown in the app UI.         |

## Ports

MeshCentral is served directly on the host (no Home Assistant Ingress):

| Container port | Default | Purpose                                        |
| -------------- | ------- | ---------------------------------------------- |
| `443/tcp`      | `8443`  | HTTPS web UI and agent connections.            |
| `80/tcp`       | `8080`  | HTTP redirect.                                 |

You can remap the host ports from the app's **Network** tab.

## License

MeshCentral is licensed under the Apache-2.0 license. See the
[MeshCentral repository](https://github.com/Ylianst/MeshCentral) for details.

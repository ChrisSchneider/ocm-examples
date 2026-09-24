# OCM Component Examples

Examples of OCM components covering different resource and access type combinations.

## Example Components

### [1-zot-registry](components/1-zot-registry.yml)

Demonstrates a real-world component using an OCI registry (Zot) as the delivery target. Covers multi-arch images, Helm charts, platform-specific binaries via `wget`, and a source reference:

| Resource | Type | Access Type | Notes |
|---|---|---|---|
| `zot` | `ociImage` | `ociArtifact/v1` | multi-arch index |
| `zli` | `executable` | `wget/v1` | linux/amd64 |
| `zli` | `executable` | `wget/v1` | linux/arm64 |
| `zot-chart` | `helmChart` | `ociArtifact/v1` | OCI Helm |
| `zot-source` | `git` | `gitHub/v1` | source repo |


### [2-known-vulnerabilities](components/2-known-vulnerabilities.yml)

Component carrying intentionally vulnerable artifacts across multiple access types — useful for testing CVE scanners and OCM-integrated security tooling.

| Resource | Type | Access | Notes |
|---|---|---|---|
| `nginx-image-as-oci-artifact` | `ociImage/v1` | `ociArtifact/v1` | nginx 1.14.0 image, OCI ref |
| `nginx-image-as-local-blob` | `ociArtifact/v1` | `LocalBlob/v1` | nginx 1.14.0 image, embedded |
| `kubectl-via-wget` | `executable` | `wget/v1` | kubectl 1.20.0, URL ref |
| `kubectl-in-s3` | `executable` | `s3/v2` | kubectl 1.20.0, S3 ref |
| `kubectl-as-local-blob` | `executable` | `LocalBlob/v1` | kubectl 1.20.0, embedded |
| `dir-with-log4j-as-oci-artifact` | `directoryTree` | `ociArtifact/v1` | dir with log4j JAR, OCI ref |
| `dir-with-log4j-in-s3` | `directoryTree` | `s3/v2` | dir with log4j JAR, S3 ref |
| `dir-with-log4j-as-local-blob` | `blob` | `LocalBlob/v1` | dir with log4j JAR, embedded |
| `sbom-as-oci-artifact` | `sbom` | `ociArtifact/v1` | CycloneDX SBOM |

Vulnerabilities:

* executable kubectl-v1.20.0 with CVE-2021-25741 (symlink path traversal)
* directory with log4j-core-2.14.1.jar with CVE-2021-44228 (Log4Shell)
* nginx 1.14.0 container image with CVE-2019-9511, CVE-2019-9513 & dozens of Debian base CVEs


### [3-scan-control-labels](components/3-scan-control-labels.yml)

Examples of `odg.ocm.software/binary-scan-policy` and `odg.ocm.software/source-scan-policy` labels — both current and legacy variants — at component and resource level

| Component | Scope | Policy |
|---|---|---|
| `scan-control-skip-component` | component | skip all |
| `scan-control-skip-some-resources` | per resource | scan / skip |
| `scan-control-skip-component-legacy` | component | skip all (legacy labels) |
| `scan-control-skip-some-resources-legacy` | per resource | scan / skip (legacy labels) |
| `scan-control` | — | umbrella |

### [9-all](components/9-all.yml)

Umbrella component, referencing all above components


## Hosting the components locally

**Open as Dev Container to run the commands (they run against Docker-internal hostnames)**

The repo works best together with odg-core opened as Dev Container.
To run standalone, run `docker network create odg-core_devcontainer_default` before opening.

### Setup local tools

* **zot** OCI registry running on https://localhost:3443 (`ocmuser` / `ocmpassword`)
* **garage** S3-compatible store, running on `localhost:3900` (`ocmuser` / `ocmpassword`)

**Outside of the Dev Container on your Host**

```sh
# Create local CA:
mkcert -install

# Create TLS certs for zot (needed for ODG):
mkcert -cert-file "zot/certs/tls.crt" -key-file "zot/certs/tls.key" localhost zot zot.test

# start the services with docker-compose
docker-compose up -d
```

Then continue in the Dev Container:

```sh
# Create garage bucket & user:
./garage/init.sh

# Log into zot & generate .dockerconfig.json
skopeo login zot.test:3443 --username ocmuser --password ocmpassword --authfile .dockerconfig.json
```

### Build the components

```sh
# Download & create blobs
./blobs/download.sh

# Push blobs and OCM components to OCI registry & S3 bucket
./components/upload.sh
```

*Hint: The project's `./ocmconfig` points to `.dockerconfig.json`. If login fails, you might have a competing config. Check the merged config with `ocm get config`*

## Hints for scanning components with Trivy

Examples to find CVEs before OCM transfer:

* `trivy rootfs --scanners vuln blobs/kubectl-v1.20.0-linux-amd64` (not found with trivy fs)
* `trivy image --scanners vuln --input blobs/nginx-oci-layout`
* `trivy rootfs --scanners vuln blobs/vuln-dir/` (not found with trivy fs)

Examples to find CVEs after OCM transfer:

| Resource | Result | Notes |
|---|---|---|
| `nginx-image-as-oci-artifact` | Found | `trivy image` with URL |
| `nginx-image-as-local-blob` | Found | `trivy image` on digest from `localReference` |
| `kubectl-as-wget` | Not Found | Trivy skips: file is no longer `+x` after `wget` |
| `kubectl-as-local-blob` | Not Found | Trivy skips: file is no longer `+x` after `oras blob fetch` (`trivy image` on blob gives `manifest unknown`) |
| `kubectl-in-s3` | Not Found | Trivy skips: file is no longer `+x` after S3 download |
| `dir-with-log4j-as-oci-artifact` | Found | `oras pull`, untar, `trivy rootfs` (`trivy image` gives `unsupported artifact type`) |
| `dir-with-log4j-as-local-blob` | Found | `oras blob fetch`, untar, `trivy rootfs` (`trivy image` on blob gives `manifest unknown`) |
| `dir-with-log4j-in-s3` | Found | `trivy rootfs` on S3 download |


## Import in Open Delivery Gear

The following example shows how you can configure ODG when it runs in a Dev Container.
Therefore Zot and Garage run in the same Docker network (`odg-core_devcontainer_default`).

Configure ODG to work with Zot and Garage:

* If running ODG in container:
  * Copy CA certs from `$(mkcert -CAROOT)/rootCA.pem` to `/usr/local/share/ca-certificates/rootCA.crt`
  * Run `sudo update-ca-certificates`
* Set `export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt` (or to your local CA trust store)
  so that Python requests lib picks up the custom CA
* Point S3 to Garage instead of AWS:
  * `AWS_ENDPOINT_URL=http://garage.test:3900`y)
  * `AWS_REQUEST_CHECKSUM_CALCULATION=when_required`
  * `AWS_RESPONSE_CHECKSUM_VALIDATION=when_required`

Add to `extensions_cfg`, e.g. to *artefact_enumerator*:

```yaml
artefact_enumerator:
  enabled: True
  components:
    - component_name: chrisschneider.dev/ocm-examples
      ocm_repo_url: zot.test:3443
```

Add component in `src/features/features_cfg.yaml`:

```yaml
- id: 03e237b4-434e-4e1c-b786-5ceb6cc76c1e
  name: chrisschneider.dev/ocm-examples
  displayName: OCM Examples
  type: ODG
  version: greatest
  icon: home
  dependencies: []
```

Add to `src/odg/ocm_repo_mappings.yaml`:

```yaml
- repository: zot.test:3443
  prefixes: chrisschneider.dev
```

Create `src/secrets/aws/local-garage.yaml`:

```yaml
access_key_id: GK626462227e739523e7936f5f
secret_access_key: 876ae9b4f20503bea48674e34c2da95d581626721131d54c5a3257e0b21c725d
region: garage
```

Create `src/secrets/oci-registry/local-zot.yaml`:

```yaml
privileges: readonly
username: ocmuser
password: ocmpassword
image_reference_prefixes:
  - zot.test:3443
```

# OCM Example Components

Test examples of OCM components covering resource and access type combinations, available at:

* Repo: `ghcr.io/chrisschneider`
* Component: `chrisschneider.dev/ocm-examples`

### [1-zot-registry](examples/1-zot-registry.yml)

Demonstrates a real-world component using an OCI registry (Zot) as the delivery target. Covers multi-arch images, Helm charts, platform-specific binaries via `wget`, and a source reference

| Resource | Type | Kind: Type | Notes |
|---|---|---|---|
| `zot` | `ociImage` | a: `ociArtifact/v1` | multi-arch index |
| `zli` | `executable` | a: `wget/v1` | linux/amd64 |
| `zli` | `executable` | a: `wget/v1` | linux/arm64 |
| `zot-chart` | `helmChart` | a: `ociArtifact/v1` | OCI Helm |
| `zot-source` | `git` | a: `gitHub/v1` | source at v2.1.0 |

### [2-known-vulnerabilities](examples/2-known-vulnerabilities.yml)

Component carrying intentionally vulnerable artifacts across multiple access types — useful for testing CVE scanners and OCM-integrated security tooling. Each logical artifact appears in up to three forms (OCI/S3/embedded) to exercise different access paths with the same content.

| Resource | Type | Kind: Type | Notes |
|---|---|---|---|
| `nginx-oci` | `ociImage` | a: `ociArtifact/v1` | nginx 1.14.0, CVE-2019-9511 |
| `nginx-local` | `ociImage` | i: `file` | same image, OCI layout tar embedded |
| `kubectl-wget` | `executable` | a: `wget/v1` | kubectl 1.20.0, CVE-2021-25741 |
| `kubectl-s3` | `executable` | a: `s3/v2` | same binary, local garage S3 |
| `kubectl-local` | `executable` | i: `file` | same binary, embedded local file |
| `lodash` | `npmPackage` | a: `npm/v1` | 4.17.15, CVE-2021-23337 + CVE-2020-28500 |
| `vuln-dir-oras` | `directoryTree` | a: `ociArtifact/v1` | log4j-core 2.14.1 JAR, CVE-2021-44228, local Zot |
| `vuln-dir-s3` | `directoryTree` | a: `s3/v2` | same tarball, local garage S3 |
| `vuln-dir-local` | `directoryTree` | i: `file` | same tarball, embedded at component creation |
| `sbom-oras` | `sbom` | a: `ociArtifact/v1` | CycloneDX, CVE-2021-44228 + CVE-2021-23337 |

### [3-scan-control-labels](examples/3-scan-control-labels.yml)

Examples of `odg.ocm.software/binary-scan-policy` and `odg.ocm.software/source-scan-policy` labels — both current and legacy variants — applied at component and resource level.

| Component | Scope | Policy |
|---|---|---|
| `scan-control-skip-component` | component | skip all |
| `scan-control-skip-some-resources` | per resource | scan / skip |
| `scan-control-skip-component-legacy` | component | skip all (legacy labels) |
| `scan-control-skip-some-resources-legacy` | per resource | scan / skip (legacy labels) |
| `scan-control` | — | umbrella |


---

## Background

OCM ...

### Artifact Types

OCM ...

| Type | Description |
|---|---|
| `ociImage` | OCI container image or multi-platform index |
| `ociArtifact` | Generic OCI registry content (e.g. ORAS-pushed data) |
| `sbom` | Software Bill of Materials (CycloneDX, SPDX, Syft) |
| `helmChart` | Helm chart (OCI Helm or classic HTTP chart repo) |
| `gitOpsTemplate` | Filesystem archive for GitOps/CD frameworks |
| `npmPackage` | npm package tarball |
| `executable` | Compiled binary; multi-arch via `extraIdentity` |
| `directoryTree` | Tarball of a directory tree |
| `blob` | Opaque bytes |
| `git` | Source code repository snapshot |

Full spec: [OCM artifact types](https://github.com/open-component-model/ocm-spec/blob/main/doc/04-extensions/01-artifact-types/README.md)

---

## Access and Input Types

OCM resources declare where their content lives in one of two ways:

- **`access`** (`a:`) — points to content that already exists somewhere (OCI registry, S3, HTTP, npm, GitHub). Used for `external` resources.
- **`input`** (`i:`) — embeds content from a local file or directory at component creation time. The OCM CLI stores it as `localBlob/v1` in the resulting archive. Used for `local` resources.

`localBlob/v1` is also what OCM sets on any resource after `ocm transfer` copies it into a component archive, regardless of the original access type.

| Type | Kind | Description |
|---|---|---|
| `ociArtifact/v1` | a | Artifact stored in an OCI registry |
| `localBlob/v1` | a | Artifact embedded in the OCM archive (set by transfer or input) |
| `wget/v1` | a | HTTP/HTTPS download |
| `s3/v1`, `s3/v2` | a | AWS S3 or S3-compatible object storage |
| `helm/v1` | a | Helm chart repository (HTTP or OCI) |
| `gitHub/v1` | a | GitHub source tree at a specific commit |
| `npm/v1` | a | npm registry |
| `ociImageLayer/v1` | a | Single OCI blob by digest |
| `file` | i | Single local file embedded as a blob |
| `dir` | i | Local directory packed as a tar archive |
| `docker` | i | Local Docker image exported and embedded |
| `helm` | i | Local Helm chart directory |

Full reference: [ocm.software/docs/reference/input-and-access-types/](https://ocm.software/docs/reference/input-and-access-types/)

---

## WIP: Building the components on your own

## Examples

Log into `ghcr.io` with your GitHub user:

    gh auth token | oras login ghcr.io --registry-config .dockerconfig.json \
    --username "$(gh api user --jq .login)" --password-stdin

*Hint: The project's `./ocmconfig` points to `.dockerconfig.json` and includes S3 credentials. If login to ghcr.io fails, you might have a competing config. Check the merged config with `ocm get config`*

*Hint: Run `gh auth login --scopes write:packages` before to also get write permissions to your GH registry*

Run the scripts in `scripts/` to prepare local resources and create the OCM components:

```sh
# Download blobs (nginx OCI layout, kubectl binary, log4j jar + tarballs)
./scripts/download-example-blobs.sh

# Push blobs and OCM components to the registry and S3
./scripts/upload.sh [--registry <host:port>] [--s3-url <url>]
```

---

## WIP: Setting up the Local Registries

**Prerequisites:**

* `docker compose`
* `mkcert`
* `oras`
* `skopeo`
* `aws` (AWS CLI v2)
* `ocm` (OCM CLI)
* `gh` (GitHub CLI, for ghcr.io auth) - logged into your GitHub account

```sh
cd local-registries-wip

# 0. If needed, create local mkcert CA first:
mkcert -install

# 1. Create TLS certs:
mkcert -cert-file "zot/certs/tls.crt" -key-file "zot/certs/tls.key" localhost 127.0.0.1 registry.internal

# 2. Point your computer IP to registry.internal

TODO: add to /etc/hosts

TODO: Why not localhost? --> OCM component references

# 3. Start registry with `docker-compose.yaml`:
docker-compose up
```

| Service | Type | Port | Purpose |
|---|---|---|---|
| **zot** | OCI registry | `https://localhost:10500` | `ociArtifact/v1`, `ociImage`, OCI Helm |
| **garage** | S3-compatible store | `localhost:10900` | `s3/v1`, `s3/v2` (bucket: `ocm-examples`) |

**Credentials:** `ocmuser` / `ocmpassword` (both services).

---

## WIP: Configure ODG

`extensions_cfg`

```yaml
artefact_enumerator:
  enabled: True
  components:
    - component_name: chrisschneider.dev/ocm-examples
      ocm_repo_url: localhost:10500
...
```

secrets/aws
secrets/oci-registry

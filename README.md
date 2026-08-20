# OCM Example Components

Test examples of OCM components covering resource and access type combinations

**Prerequisites:**

* `docker compose`
* `oras`
* `skopeo`
* `aws` (AWS CLI v2)
* `ocm` (OCM CLI)
* `gh` (GitHub CLI, for ghcr.io auth) - logged into your GitHub account

---

## Artifact Types

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

## Setting up the Local Registries

`local-registries/docker-compose.yml` spins up two services for local testing:

| Service | Type | Port | Purpose |
|---|---|---|---|
| **zot** | OCI registry | `localhost:10500` | `ociArtifact/v1`, `ociImage`, OCI Helm |
| **garage** | S3-compatible store | `localhost:10900` | `s3/v1`, `s3/v2` (bucket: `ocm-examples`) |

**Credentials:** `ocmuser` / `ocmpassword` (both services).

Start with:

    cd local-registries
    docker-compose up

---

## Examples

Log into `ghcr.io` with your GitHub user:

    gh auth token | oras login ghcr.io --registry-config .dockerconfig.json \
    --username "$(gh api user --jq .login)" --password-stdin

Run `prepare.sh` to download local resources, push to Zot/S3 and create the OCM component:

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

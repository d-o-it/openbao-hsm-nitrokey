# openbao-hsm-nitrokey

[OpenBao](https://openbao.org/) container image with PKCS#11 auto-unseal
support for the [Nitrokey HSM](https://www.nitrokey.com/products/hsm), built on
the official `openbao/openbao` image.

## What it does

The image extends the standard OpenBao distribution with the two pieces
required to unseal against a Nitrokey HSM — nothing else:

1. **OpenSC + pcsc-lite libraries** (`opensc`, `pcsc-lite-libs` from Alpine) —
   provide `opensc-pkcs11.so`, the PKCS#11 module that talks to the Nitrokey
   through a `pcscd` smartcard daemon (typically mounted into the container as
   a host socket).
2. **The [`kms-pkcs11` seal plugin](https://github.com/openbao/openbao-plugins)**,
   compiled from source with musl cgo and installed at
   `/opt/openbao/plugins/openbao-plugin-kms-pkcs11`. Its SHA-256 checksum is
   baked next to the binary
   (`/opt/openbao/plugins/openbao-plugin-kms-pkcs11.sha256`) and printed in the
   CI build log, because the OpenBao server configuration must pin it.

The OpenBao binary itself is bit-for-bit the official release — this image
only adds the HSM plumbing.

## Why it is necessary

- **OpenBao removes the built-in `pkcs11` seal in v2.7.0.** Auto-unseal
  mechanisms move to external
  [KMS plugins](https://openbao.org/docs/configuration/seal/#plugins), and the
  cgo-based HSM distribution of OpenBao is discontinued. See the
  [v2.6.0 release notes](https://openbao.org/docs/release-notes/2-6-0/).
- **The official image cannot do PKCS#11 on its own.** `openbao/openbao`
  ships neither OpenSC nor the seal plugin, and there is no configuration-level
  way to inject a shared library into it.
- **The upstream prebuilt plugin does not run on Alpine.** The binaries
  published in [openbao-plugins](https://github.com/openbao/openbao-plugins/releases)
  are glibc-linked, while the official OpenBao image is Alpine/musl — and the
  plugin must share a libc with the `opensc-pkcs11.so` it `dlopen`s. Hence the
  multi-stage build compiling the plugin with musl cgo.

## Usage

Register the plugin and the seal in the server configuration
([declarative plugins](https://openbao.org/docs/configuration/plugins/),
[pkcs11 seal](https://openbao.org/docs/configuration/seal/pkcs11/)):

```hcl
plugin_directory = "/opt/openbao/plugins"

plugin "kms" "pkcs11" {
  command   = "openbao-plugin-kms-pkcs11"
  sha256sum = "<contents of /opt/openbao/plugins/openbao-plugin-kms-pkcs11.sha256>"
}
```

The seal itself can be configured via the `seal "pkcs11"` stanza or the
`BAO_SEAL_TYPE=pkcs11` / `BAO_HSM_*` environment variables, e.g.:

```
BAO_SEAL_TYPE=pkcs11
BAO_HSM_LIB=/usr/lib/pkcs11/opensc-pkcs11.so
BAO_HSM_SLOT=0
BAO_HSM_KEY_LABEL=<key label on the HSM>
BAO_HSM_PIN=<pin>
```

A running `pcscd` with the Nitrokey attached must be reachable from the
container — e.g. mount the host's `/run/pcscd/pcscd.comm` socket.

> **Checksum pin:** whenever the image is rebuilt with a different Go builder
> digest or plugin version, the plugin binary — and therefore the `sha256sum`
> to pin — can change. Read the new value from the `.sha256` file in the image
> (or the CI build log) and update the server configuration together with the
> image tag.

## Builds and tags

A [scheduled workflow](.github/workflows/build-image.yml) checks for new
OpenBao releases every 12 hours and pushes
`ghcr.io/d-o-it/openbao-hsm-nitrokey:<version>` (plus `latest`). Manual runs
accept `force` (rebuild an existing version) and `tag_suffix` (publish under a
distinct tag instead of overwriting a deployed one). The Go builder is pinned
by digest so rebuilds reproduce an identical plugin binary.

## Links

- [OpenBao](https://openbao.org/) · [GitHub](https://github.com/openbao/openbao)
- [Seal configuration & KMS plugins](https://openbao.org/docs/configuration/seal/#plugins)
- [pkcs11 seal documentation](https://openbao.org/docs/configuration/seal/pkcs11/)
- [Declarative plugin configuration](https://openbao.org/docs/configuration/plugins/)
- [openbao-plugins (plugin source & releases)](https://github.com/openbao/openbao-plugins)
- [OpenBao v2.6.0 release notes (seal pluginization & HSM deprecation)](https://openbao.org/docs/release-notes/2-6-0/)
- [Nitrokey HSM](https://www.nitrokey.com/products/hsm)

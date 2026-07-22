# Build the PKCS#11 KMS seal plugin from source with musl cgo so it runs on
# the Alpine base image and can dlopen the apk-installed opensc-pkcs11.so.
# The upstream prebuilt plugin binaries are glibc-linked and unusable here.
# Needed because the built-in pkcs11 seal is removed in OpenBao v2.7.0.
FROM golang:1.26-alpine AS plugin-builder

ARG KMS_PKCS11_VERSION=kms-pkcs11-v0.1.0

RUN apk add --no-cache git gcc musl-dev

RUN git clone --depth 1 --branch ${KMS_PKCS11_VERSION} https://github.com/openbao/openbao-plugins /src

WORKDIR /src

RUN CGO_ENABLED=1 go build -trimpath -o /openbao-plugin-kms-pkcs11 ./kms/pkcs11/cmd

# Use the Alpine-based HSM image
ARG BAO_VERSION=latest
FROM openbao/openbao-hsm:${BAO_VERSION}

USER root

# Alpine's package manager is incredibly reliable for this
RUN apk add --no-cache opensc pcsc-lite-libs

# Install the seal plugin. The server config pins plugin.sha256sum; the value
# for the deployed image tag is baked next to the binary and printed in the
# build log (refresh the pinned value whenever the image is rebuilt).
# Ownership/permissions satisfy VAULT_ENABLE_FILE_PERMISSIONS_CHECK.
COPY --from=plugin-builder --chown=openbao:openbao /openbao-plugin-kms-pkcs11 /opt/openbao/plugins/openbao-plugin-kms-pkcs11
RUN chmod 0755 /opt/openbao/plugins/openbao-plugin-kms-pkcs11 \
  && sha256sum /opt/openbao/plugins/openbao-plugin-kms-pkcs11 | tee /opt/openbao/plugins/openbao-plugin-kms-pkcs11.sha256 \
  && chown -R openbao:openbao /opt/openbao/plugins \
  && chmod 0755 /opt/openbao/plugins

# Switch back to the openbao user
USER openbao

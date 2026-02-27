# Use the Alpine-based HSM image
ARG BAO_VERSION=latest
FROM openbao/openbao-hsm:${BAO_VERSION}

USER root

# Alpine's package manager is incredibly reliable for this
RUN apk add --no-cache opensc pcsc-lite-libs

# Switch back to the bao user
USER bao
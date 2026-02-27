# We will pass the version as an argument
ARG BAO_VERSION=latest
FROM openbao/openbao-hsm-ubi:${BAO_VERSION}

USER root

# Install OpenSC and PC/SC Lite natively
RUN microdnf update -y && \
    microdnf install -y opensc pcsc-lite-libs && \
    microdnf clean all
    
USER bao
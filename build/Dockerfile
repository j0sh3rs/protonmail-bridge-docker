# Alpine-based Golang build for ProtonMail Bridge
FROM golang:alpine AS build

ARG version

# Install build dependencies
RUN apk add --no-cache \
  bash \
  git \
  make \
  gcc \
  musl-dev \
  libsecret-dev \
  pkgconfig \
  libc-dev

# Build
ADD https://github.com/ProtonMail/proton-bridge.git#${version} /build/
WORKDIR /build/
RUN make build-nogui vault-editor

FROM alpine:latest
LABEL maintainer="Josh Simmonds <github@beholdthehurricane.com>"

EXPOSE 25/tcp
EXPOSE 143/tcp

# Install runtime dependencies
RUN apk add --no-cache \
  bash \
  dbus \
  dbus-x11 \
  socat \
  pass \
  gnupg \
  procps-ng \
  libsecret \
  ca-certificates \
  coreutils \
  && rm -rf /var/cache/apk/*

# Copy bash scripts
COPY gpgparams entrypoint.sh /protonmail/

# Copy protonmail binaries
COPY --from=build /build/bridge /protonmail/
COPY --from=build /build/proton-bridge /protonmail/
COPY --from=build /build/vault-editor /protonmail/

ENTRYPOINT ["bash", "/protonmail/entrypoint.sh"]

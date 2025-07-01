# Alpine Conversion Notes

## Changes Made

The Dockerfile has been converted from `debian:sid-slim` to Alpine Linux with the following key changes:

### Build Stage Changes
- **Base Image**: `debian:sid-slim` → `golang:alpine`
- **Package Manager**: `apt-get` → `apk`
- **Dependencies**:
  - `golang` → Already included in `golang:alpine`
  - `build-essential` → `make`, `gcc`, `musl-dev`
  - `libsecret-1-dev` → `libsecret-dev`
  - Added `git` and `pkgconfig` for build requirements

### Runtime Stage Changes
- **Base Image**: `debian:sid-slim` → `alpine:latest`
- **Dependencies**:
  - `socat` → `socat` (same)
  - `pass` → `pass` + `gnupg`
  - `procps` → `procps` (same)
  - `libsecret-1-0` → `libsecret`
  - `ca-certificates` → `ca-certificates` (same)
  - Added `bash` (required for entrypoint.sh)

## Potential Issues & Considerations

### 1. Architecture Support
The original Dockerfile had a comment about riscv64 support:
```
# The build image could be golang, but it currently does not support riscv64. Only debian:sid does, at the time of writing.
```

If you need riscv64 support, you may need to stick with the Debian version or use a different approach.

### 2. Library Compatibility
- Alpine uses musl libc instead of glibc, which could cause compatibility issues with some Go programs
- The ProtonMail Bridge might have specific requirements that work better with glibc

### 3. Pass/GPG Differences
- The `pass` password manager in Alpine might behave slightly differently
- GPG key generation and storage paths could differ

## Testing the Conversion

### 1. Build Test
```bash
# Test the build process
docker build -t protonmail-bridge-alpine --build-arg version=v3.0.21 .
```

### 2. Runtime Test
```bash
# Test basic functionality
docker run --rm -it protonmail-bridge-alpine /bin/bash -c "
  echo 'Testing basic dependencies:'
  which socat && echo '✓ socat found'
  which pass && echo '✓ pass found'
  which gpg && echo '✓ gpg found'
  which pkill && echo '✓ pkill found'
  ls -la /protonmail/
"
```

### 3. Full Integration Test
```bash
# Test the actual bridge initialization (requires interactive input)
docker run --rm -it protonmail-bridge-alpine init
```

## Fallback Options

If the Alpine conversion causes issues, consider these alternatives:

### 1. Hybrid Approach
Use `golang:alpine` for build stage but keep `debian:sid-slim` for runtime:
```dockerfile
FROM golang:alpine AS build
# ... build stage ...

FROM debian:sid-slim
# ... runtime stage ...
```

### 2. Distroless Alternative
Use Google's distroless images for a smaller attack surface:
```dockerfile
FROM golang:alpine AS build
# ... build stage ...

FROM gcr.io/distroless/base-debian11
# ... runtime stage ...
```

### 3. Ubuntu Alternative
Use Ubuntu instead of Debian if sid-specific features aren't required:
```dockerfile
FROM golang:alpine AS build
# ... build stage ...

FROM ubuntu:22.04
# ... runtime stage ...
```

## Size Comparison

The Alpine version should be significantly smaller:
- **Original (Debian)**: ~300-400MB
- **Alpine**: ~150-200MB (estimated)

Run `docker images` after building both versions to compare actual sizes.

## Verification Checklist

- [ ] Build completes without errors
- [ ] All binaries are present in `/protonmail/`
- [ ] Basic dependencies are installed and functional
- [ ] GPG key generation works
- [ ] Pass initialization works
- [ ] Bridge can start and accept connections
- [ ] SMTP/IMAP proxying works correctly
- [ ] No runtime errors in logs

## Notes for Specific Versions

Make sure to test with the specific ProtonMail Bridge version you're using, as different versions might have different requirements.

Current supported versions can be found at: https://github.com/ProtonMail/proton-bridge/releases

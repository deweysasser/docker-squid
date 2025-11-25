# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Docker-containerized Squid proxy server with SSL support, designed for transparent proxying of HTTP and HTTPS traffic. The proxy supports two modes: whitelist-based filtering and allow-all (logging only) mode.

## Building and Running

Build the Docker image:
```bash
make build
# or: docker build -t squid .
```

Run tests:
```bash
make test
```

Run the container with whitelist:
```bash
docker run -d --name squid --net host -v /etc/squid/whitelist.txt:/etc/squid/whitelist.txt deweysasser/squid:latest
```

Run in allow-all mode (just logging, no filtering):
```bash
docker run -d --name squid --net host -e ALLOW_ALL_TRAFFIC=true deweysasser/squid:latest
```

## Testing

The test suite (`test.sh`) validates all configuration permutations:
- 8 test scenarios covering combinations of whitelist/blocklist presence and ALLOW_ALL_TRAFFIC setting
- Tests verify blocklist precedence, whitelist filtering, and allow-all behavior
- Automatically builds image, runs containers, and tests HTTP requests through proxy
- GitHub Actions runs tests on every push to master/main branches

## Architecture

### Port Configuration
- **3128**: Standard proxy port
- **3129**: Transparent HTTP proxy (intercept mode)
- **3127**: Transparent HTTPS proxy (SSL bump intercept mode)

### Configuration System

The configuration uses a templating approach via `dockerize`:
1. `squid.conf` is actually a template (`squid.conf.templ`) with Go template syntax
2. The `ALLOW_ALL_TRAFFIC` environment variable controls conditional blocks
3. At runtime, `dockerize` processes the template and generates the final `/etc/squid/squid.conf`

### Blocklist, Whitelist, and Allow-All Modes

**Blocklist** (always active):
- Reads domains from `/etc/squid/blocklist.txt`
- Takes precedence over both whitelist and allow-all modes
- Each domain should have a leading period (e.g., `.facebook.com`)
- ACLs `blocklist` and `sslBlocklist` are defined for HTTP and HTTPS blocking
- Deny rules are applied first in squid.conf:47 (HTTP) and squid.conf:30 (SSL)
- If file is not mounted, an empty file is created during build (Dockerfile:7)

**Whitelist Mode** (default, `ALLOW_ALL_TRAFFIC=false`):
- Reads domains from `/etc/squid/whitelist.txt`
- Each domain should have a leading period (e.g., `.google.com`)
- ACLs `whitelist` and `sslWhitelist` are defined for HTTP and HTTPS filtering
- Only whitelisted domains are allowed through (after blocklist check)

**Allow-All Mode** (`ALLOW_ALL_TRAFFIC=true`):
- Bypasses whitelist checks
- Uses `ssl_bump splice` to allow all SSL traffic at step1
- Allows all HTTP traffic via `http_access allow all`
- Blocklist still enforced before allowing traffic
- Still logs all traffic for monitoring

### SSL Handling

The container generates a self-signed certificate during build (Dockerfile:8-11) used for SSL bumping. This certificate is NOT for MITM inspection but rather for the SSL bump process itself. The `ssl_bump` directives in squid.conf:30-41 control SSL interception behavior:
- `terminate` at step1 for blocklisted domains (squid.conf:30) - blocks before any inspection
- `peek` allows Squid to inspect SNI without breaking the connection
- `splice` passes through whitelisted/allowed connections without decryption
- `terminate` rejects non-whitelisted/non-allowed connections

### Key Files

- **Dockerfile**: Builds Alpine-based image with Squid and generates SSL cert, creates empty blocklist.txt and whitelist.txt
- **squid.conf**: Template file with conditional logic based on `ALLOW_ALL_TRAFFIC`
- **run-squid.sh**: Startup script that removes stale PID and runs Squid in foreground with debug level 9
- **whitelist.txt**: User-provided file mounted at runtime (not in repo), empty by default
- **blocklist.txt**: User-provided file mounted at runtime (not in repo), empty by default
- **test.sh**: Comprehensive test script that validates all configuration permutations
- **Makefile**: Build automation with targets for build, test, clean, and help
- **.github/workflows/test.yml**: GitHub Actions workflow for CI testing

## Important Notes

- Squid configuration is complex; changes may have unexpected effects
- The embedded SSL certificate is intentionally not secured (not used for MITM)
- Debug level is set to 9 in run-squid.sh for verbose logging
- Access logs are piped to stdout by dockerize for container log visibility

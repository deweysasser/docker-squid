# Release Notes - Blocklist Support & Testing Infrastructure

## Overview

This release adds comprehensive blocklist functionality, fixes critical Docker build issues, and introduces a complete test suite with CI/CD integration.

## New Features

### 🚫 Blocklist Support
- **Domain blocking with precedence**: Blocklist now takes priority over both whitelist and allow-all modes
- **Always active**: Blocklist filtering is enforced regardless of `ALLOW_ALL_TRAFFIC` setting
- **Automatic initialization**: Empty blocklist file created by default if not mounted
- **Dual protocol coverage**: Works for both HTTP and HTTPS traffic

#### Usage
Mount your blocklist file when running the container:
```bash
docker run -d --name squid --net host \
  -v /path/to/blocklist.txt:/etc/squid/blocklist.txt \
  deweysasser/squid:latest
```

Example `blocklist.txt` format:
```
.facebook.com
.tiktok.com
.ads.example.com
```

### 🧪 Comprehensive Test Suite
- **8 test scenarios** covering all configuration permutations
- **25 automated tests** validating:
  - Blocklist precedence enforcement
  - Whitelist filtering accuracy
  - ALLOW_ALL_TRAFFIC mode behavior
  - Empty list handling
  - HTTP and redirect handling
- **Color-coded output** for easy result interpretation
- **Automated container lifecycle** management

#### Running Tests
```bash
make test
```

### 🔧 Build Automation
New Makefile with convenient targets:
- `make build` - Build the Docker image
- `make test` - Run the complete test suite
- `make clean` - Clean up Docker resources
- `make all` - Build and test in one command
- `make help` - Display available targets

### 🤖 CI/CD Integration
- **GitHub Actions workflow** runs tests on every push
- **Automated validation** of all configuration modes
- **Pull request testing** support

## Bug Fixes

### Critical Docker Build Issues
- **Fixed base image**: Switched from `jwilder/dockerize` to Alpine Linux + dockerize installation
  - Resolves "no such file or directory" errors for `/bin/sh`
  - Ensures proper shell availability for all RUN commands

- **Fixed Squid SSL crashes**:
  - Initialize SSL certificate database (`ssl_db`) during build
  - Configure `sslcrtd_program` properly in squid.conf
  - Prevents "sslcrtd_program helpers are crashing" fatal errors

- **Fixed cache initialization**:
  - Move squid cache initialization to build time
  - Eliminates PID file conflicts on startup
  - Ensures containers start reliably

### Configuration Improvements
- Added proper SSL certificate helper configuration
- Set correct permissions for squid directories
- Fixed cache directory initialization timing

## Technical Improvements

### Docker Image
- **Base**: Alpine Linux 3.22+ (was: jwilder/dockerize)
- **Squid**: Version 6.12
- **Dockerize**: v0.7.0 (dynamically installed)
- **SSL Database**: Pre-initialized 4MB certificate cache

### Configuration Architecture
- Blocklist ACLs processed before all allow rules
- SSL bump terminates blocklisted connections at step1
- HTTP access denies blocklisted domains before Safe_ports checks
- Empty ACL warnings are safe and expected for unmounted lists

### Documentation
- **CLAUDE.md**: Comprehensive architecture and development guide
- **README.md**: Updated with blocklist usage and testing instructions
- **Inline comments**: Added clarifying comments to squid.conf

## Testing Results

All 25 tests passing ✅:
- ✅ Test 1: No files, ALLOW_ALL_TRAFFIC=false (2 tests)
- ✅ Test 2: No files, ALLOW_ALL_TRAFFIC=true (2 tests)
- ✅ Test 3: Whitelist only, ALLOW_ALL_TRAFFIC=false (3 tests)
- ✅ Test 4: Whitelist only, ALLOW_ALL_TRAFFIC=true (2 tests)
- ✅ Test 5: Blocklist only, ALLOW_ALL_TRAFFIC=false (3 tests)
- ✅ Test 6: Blocklist only, ALLOW_ALL_TRAFFIC=true (4 tests)
- ✅ Test 7: Both lists, ALLOW_ALL_TRAFFIC=false (5 tests)
- ✅ Test 8: Both lists, ALLOW_ALL_TRAFFIC=true (4 tests)

## Upgrade Instructions

### For Existing Users

1. **Rebuild your image** to get the fixes:
   ```bash
   docker pull deweysasser/squid:latest
   # or
   docker build -t squid .
   ```

2. **Optional: Add a blocklist**:
   ```bash
   # Create blocklist file
   echo ".unwanted-domain.com" > /etc/squid/blocklist.txt

   # Mount it when running
   docker run -d --name squid --net host \
     -v /etc/squid/whitelist.txt:/etc/squid/whitelist.txt \
     -v /etc/squid/blocklist.txt:/etc/squid/blocklist.txt \
     deweysasser/squid:latest
   ```

3. **No breaking changes**: Existing configurations continue to work

### Verification

Test your setup:
```bash
# Clone the repository
git clone https://github.com/deweysasser/docker-squid.git
cd docker-squid

# Run tests
make test
```

## Breaking Changes

**None** - This release is fully backward compatible. Existing whitelist and ALLOW_ALL_TRAFFIC configurations work unchanged.

## Files Changed

- `Dockerfile` - Fixed base image and added SSL database initialization
- `squid.conf` - Added blocklist ACLs and sslcrtd_program configuration
- `run-squid.sh` - Improved PID file handling
- `test.sh` - New comprehensive test suite (executable)
- `Makefile` - New build automation
- `.github/workflows/test.yml` - New CI/CD workflow
- `README.md` - Updated documentation
- `CLAUDE.md` - New architecture guide
- `.gitignore` - Added (ignores IDE files)

## Contributors

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>

## What's Next

Future enhancements under consideration:
- HTTPS transparent proxy testing in test suite
- Support for regex patterns in blocklist/whitelist
- Performance benchmarking tests
- Docker image size optimization
- Multi-architecture builds (ARM support)

---

For questions or issues, please visit: https://github.com/deweysasser/docker-squid/issues

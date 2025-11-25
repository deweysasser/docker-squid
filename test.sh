#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

IMAGE_NAME="squid-test"
CONTAINER_NAME="squid-test-container"
TEST_DIR="/tmp/squid-test-$$"

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    rm -rf "$TEST_DIR"
}

# Setup trap for cleanup
trap cleanup EXIT

# Test result tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_proxy() {
    local test_name="$1"
    local url="$2"
    local expected_result="$3"  # "allow" or "deny"
    local first_test_in_scenario="$4"  # "first" or empty

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -n "  Testing $test_name... "

    # Wait for squid to be ready if this is the first test in a scenario
    if [ "$first_test_in_scenario" == "first" ]; then
        sleep 5
    else
        # Small delay between tests to avoid rate limiting
        sleep 1
    fi

    # Try to fetch through the proxy and check HTTP status code
    http_code=$(curl -x http://localhost:3128 -m 5 -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

    # 200-399 = success/allow (includes redirects), 403 = denied by proxy, anything else = deny
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
        result="allow"
    else
        result="deny"
    fi

    if [ "$result" == "$expected_result" ]; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC} (expected $expected_result, got $result)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Print test header
print_test_header() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

# Build the image
echo -e "${GREEN}Building Docker image...${NC}"
docker build -t "$IMAGE_NAME" .

# Create test directory
mkdir -p "$TEST_DIR"

# Create test files
echo ".example.com" > "$TEST_DIR/whitelist.txt"
echo ".google.com" >> "$TEST_DIR/whitelist.txt"

echo ".blocked.com" > "$TEST_DIR/blocklist.txt"
echo ".facebook.com" >> "$TEST_DIR/blocklist.txt"

echo -e "${GREEN}Test files created in $TEST_DIR${NC}"

# Test 1: No files, ALLOW_ALL_TRAFFIC=false (default whitelist mode, empty whitelist)
print_test_header "Test 1: No files, ALLOW_ALL_TRAFFIC=false"
docker run -d --name "$CONTAINER_NAME" \
    -p 3128:3128 \
    "$IMAGE_NAME"

test_proxy "example.com (not whitelisted)" "http://example.com" "deny" "first"
test_proxy "google.com (not whitelisted)" "http://google.com" "deny"

docker stop "$CONTAINER_NAME" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null

# Test 2: No files, ALLOW_ALL_TRAFFIC=true
print_test_header "Test 2: No files, ALLOW_ALL_TRAFFIC=true"
docker run -d --name "$CONTAINER_NAME" \
    -p 3128:3128 \
    -e ALLOW_ALL_TRAFFIC=true \
    "$IMAGE_NAME"

test_proxy "example.com (should allow)" "http://example.com" "allow" "first"
test_proxy "google.com (should allow)" "http://google.com" "allow"

docker stop "$CONTAINER_NAME" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null

# Test 3: Whitelist only, ALLOW_ALL_TRAFFIC=false
print_test_header "Test 3: Whitelist only, ALLOW_ALL_TRAFFIC=false"
docker run -d --name "$CONTAINER_NAME" \
    -p 3128:3128 \
    -v "$TEST_DIR/whitelist.txt:/etc/squid/whitelist.txt" \
    "$IMAGE_NAME"

test_proxy "example.com (whitelisted)" "http://example.com" "allow" "first"
test_proxy "google.com (whitelisted)" "http://google.com" "allow"
test_proxy "yahoo.com (not whitelisted)" "http://yahoo.com" "deny"

docker stop "$CONTAINER_NAME" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null

# Test 4: Whitelist only, ALLOW_ALL_TRAFFIC=true
print_test_header "Test 4: Whitelist only, ALLOW_ALL_TRAFFIC=true"
docker run -d --name "$CONTAINER_NAME" \
    -p 3128:3128 \
    -e ALLOW_ALL_TRAFFIC=true \
    -v "$TEST_DIR/whitelist.txt:/etc/squid/whitelist.txt" \
    "$IMAGE_NAME"

test_proxy "example.com (should allow)" "http://example.com" "allow" "first"
test_proxy "yahoo.com (should allow)" "http://yahoo.com" "allow"

docker stop "$CONTAINER_NAME" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null

# Test 5: Blocklist only, ALLOW_ALL_TRAFFIC=false
print_test_header "Test 5: Blocklist only, ALLOW_ALL_TRAFFIC=false"
docker run -d --name "$CONTAINER_NAME" \
    -p 3128:3128 \
    -v "$TEST_DIR/blocklist.txt:/etc/squid/blocklist.txt" \
    "$IMAGE_NAME"

test_proxy "blocked.com (blocklisted)" "http://blocked.com" "deny" "first"
test_proxy "facebook.com (blocklisted)" "http://facebook.com" "deny"
test_proxy "example.com (not whitelisted)" "http://example.com" "deny"

docker stop "$CONTAINER_NAME" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null

# Test 6: Blocklist only, ALLOW_ALL_TRAFFIC=true
print_test_header "Test 6: Blocklist only, ALLOW_ALL_TRAFFIC=true"
docker run -d --name "$CONTAINER_NAME" \
    -p 3128:3128 \
    -e ALLOW_ALL_TRAFFIC=true \
    -v "$TEST_DIR/blocklist.txt:/etc/squid/blocklist.txt" \
    "$IMAGE_NAME"

test_proxy "blocked.com (blocklisted)" "http://blocked.com" "deny" "first"
test_proxy "facebook.com (blocklisted)" "http://facebook.com" "deny"
test_proxy "example.com (should allow)" "http://example.com" "allow"
test_proxy "google.com (should allow)" "http://google.com" "allow"

docker stop "$CONTAINER_NAME" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null

# Test 7: Both lists, ALLOW_ALL_TRAFFIC=false
print_test_header "Test 7: Both lists, ALLOW_ALL_TRAFFIC=false"
docker run -d --name "$CONTAINER_NAME" \
    -p 3128:3128 \
    -v "$TEST_DIR/whitelist.txt:/etc/squid/whitelist.txt" \
    -v "$TEST_DIR/blocklist.txt:/etc/squid/blocklist.txt" \
    "$IMAGE_NAME"

test_proxy "blocked.com (blocklisted)" "http://blocked.com" "deny" "first"
test_proxy "facebook.com (blocklisted)" "http://facebook.com" "deny"
test_proxy "example.com (whitelisted)" "http://example.com" "allow"
test_proxy "google.com (whitelisted)" "http://google.com" "allow"
test_proxy "yahoo.com (not whitelisted)" "http://yahoo.com" "deny"

docker stop "$CONTAINER_NAME" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null

# Test 8: Both lists, ALLOW_ALL_TRAFFIC=true
print_test_header "Test 8: Both lists, ALLOW_ALL_TRAFFIC=true"
docker run -d --name "$CONTAINER_NAME" \
    -p 3128:3128 \
    -e ALLOW_ALL_TRAFFIC=true \
    -v "$TEST_DIR/whitelist.txt:/etc/squid/whitelist.txt" \
    -v "$TEST_DIR/blocklist.txt:/etc/squid/blocklist.txt" \
    "$IMAGE_NAME"

test_proxy "blocked.com (blocklisted)" "http://blocked.com" "deny" "first"
test_proxy "facebook.com (blocklisted)" "http://facebook.com" "deny"
test_proxy "example.com (should allow)" "http://example.com" "allow"
test_proxy "yahoo.com (should allow)" "http://yahoo.com" "allow"

docker stop "$CONTAINER_NAME" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null

# Print summary
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo "Tests run: $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi

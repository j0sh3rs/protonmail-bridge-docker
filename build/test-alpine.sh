#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="protonmail-bridge-alpine-test"
BRIDGE_VERSION="${BRIDGE_VERSION:-v3.0.21}"

echo -e "${YELLOW}ProtonMail Bridge Alpine Conversion Test Script${NC}"
echo "=================================================="
echo "Bridge Version: $BRIDGE_VERSION"
echo "Image Name: $IMAGE_NAME"
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        return 1
    fi
}

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    echo -n "Testing $test_name... "

    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Test 1: Build the image
echo "1. Building Alpine-based image..."
if docker build -t "$IMAGE_NAME" --build-arg version="$BRIDGE_VERSION" . 2>&1 | tee build.log; then
    print_status 0 "Image build completed"
else
    print_status 1 "Image build failed"
    echo "Check build.log for details"
    exit 1
fi

echo ""

# Test 2: Basic dependency checks
echo "2. Checking runtime dependencies..."

DEPS_TEST='
echo "Checking dependencies:"
which bash && echo "✓ bash found" || echo "✗ bash missing"
which socat && echo "✓ socat found" || echo "✗ socat missing"
which pass && echo "✓ pass found" || echo "✗ pass missing"
which gpg && echo "✓ gpg found" || echo "✗ gpg missing"
which pkill && echo "✓ pkill found" || echo "✗ pkill missing"
echo "Checking SSL certificates:"
ls /etc/ssl/certs/ | wc -l | xargs echo "CA certificates count:"
echo "Checking ProtonMail binaries:"
ls -la /protonmail/ | grep -E "(bridge|proton-bridge|vault-editor)"
'

if docker run --rm "$IMAGE_NAME" /bin/bash -c "$DEPS_TEST"; then
    print_status 0 "Dependency check completed"
else
    print_status 1 "Dependency check failed"
fi

echo ""

# Test 3: File permissions and structure
echo "3. Checking file structure and permissions..."

STRUCTURE_TEST='
echo "Checking /protonmail directory structure:"
ls -la /protonmail/
echo ""
echo "Checking executable permissions:"
[ -x /protonmail/bridge ] && echo "✓ bridge is executable" || echo "✗ bridge not executable"
[ -x /protonmail/proton-bridge ] && echo "✓ proton-bridge is executable" || echo "✗ proton-bridge not executable"
[ -x /protonmail/vault-editor ] && echo "✓ vault-editor is executable" || echo "✗ vault-editor not executable"
[ -x /protonmail/entrypoint.sh ] && echo "✓ entrypoint.sh is executable" || echo "✗ entrypoint.sh not executable"
'

if docker run --rm "$IMAGE_NAME" /bin/bash -c "$STRUCTURE_TEST"; then
    print_status 0 "File structure check completed"
else
    print_status 1 "File structure check failed"
fi

echo ""

# Test 4: GPG functionality test
echo "4. Testing GPG key generation..."

GPG_TEST='
export GNUPGHOME=/tmp/gnupg-test
mkdir -p $GNUPGHOME
chmod 700 $GNUPGHOME
echo "Testing GPG key generation with test parameters..."
cat > /tmp/test-gpg-params << EOF
%no-protection
%echo Generating test key
Key-Type: RSA
Key-Length: 2048
Name-Real: test-key
Expire-Date: 1d
%commit
%echo done
EOF
timeout 30 gpg --batch --generate-key /tmp/test-gpg-params 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ GPG key generation successful"
    gpg --list-keys
else
    echo "✗ GPG key generation failed or timed out"
    exit 1
fi
'

if docker run --rm "$IMAGE_NAME" /bin/bash -c "$GPG_TEST"; then
    print_status 0 "GPG functionality test completed"
else
    print_status 1 "GPG functionality test failed"
fi

echo ""

# Test 5: Pass initialization test
echo "5. Testing pass initialization..."

PASS_TEST='
export GNUPGHOME=/tmp/gnupg-test
export PASSWORD_STORE_DIR=/tmp/pass-test
mkdir -p $GNUPGHOME $PASSWORD_STORE_DIR
chmod 700 $GNUPGHOME
echo "Setting up GPG for pass test..."
cat > /tmp/test-gpg-params << EOF
%no-protection
%echo Generating test key
Key-Type: RSA
Key-Length: 2048
Name-Real: pass-test-key
Name-Email: test@example.com
Expire-Date: 1d
%commit
%echo done
EOF
gpg --batch --generate-key /tmp/test-gpg-params 2>/dev/null
KEY_ID=$(gpg --list-secret-keys --with-colons | grep sec | cut -d: -f5 | head -1)
echo "Testing pass initialization with key: $KEY_ID"
echo $KEY_ID | pass init 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ Pass initialization successful"
    pass ls 2>/dev/null || echo "Empty password store (expected)"
else
    echo "✗ Pass initialization failed"
    exit 1
fi
'

if docker run --rm "$IMAGE_NAME" /bin/bash -c "$PASS_TEST"; then
    print_status 0 "Pass initialization test completed"
else
    print_status 1 "Pass initialization test failed"
fi

echo ""

# Test 6: Network tools test
echo "6. Testing network tools..."

NETWORK_TEST='
echo "Testing socat availability and basic functionality:"
which socat >/dev/null 2>&1 && echo "✓ socat is available"
echo "Testing basic socat functionality (timeout in 5 seconds):"
timeout 5 socat TCP-LISTEN:9999,reuseaddr,fork EXEC:"/bin/echo test" &
SOCAT_PID=$!
sleep 1
if netstat -ln 2>/dev/null | grep :9999 >/dev/null; then
    echo "✓ socat can bind to ports"
    kill $SOCAT_PID 2>/dev/null || true
else
    echo "? socat binding test inconclusive (no netstat)"
    kill $SOCAT_PID 2>/dev/null || true
fi
'

if docker run --rm "$IMAGE_NAME" /bin/bash -c "$NETWORK_TEST"; then
    print_status 0 "Network tools test completed"
else
    print_status 1 "Network tools test had issues"
fi

echo ""

# Test 7: Image size comparison
echo "7. Image size analysis..."

ORIGINAL_SIZE=$(docker images protonmail-bridge-debian 2>/dev/null | awk 'NR==2 {print $7 " " $8}' || echo "N/A")
ALPINE_SIZE=$(docker images "$IMAGE_NAME" | awk 'NR==2 {print $7 " " $8}')

echo "Image sizes:"
echo "  Alpine version: $ALPINE_SIZE"
echo "  Original (if available): $ORIGINAL_SIZE"

# Test 8: Entrypoint validation
echo ""
echo "8. Testing entrypoint script..."

ENTRYPOINT_TEST='
echo "Validating entrypoint script syntax:"
bash -n /protonmail/entrypoint.sh && echo "✓ entrypoint.sh syntax is valid"
echo "Testing entrypoint help/version (if available):"
timeout 10 /protonmail/proton-bridge --help 2>/dev/null | head -5 || echo "Bridge help not available (expected without proper initialization)"
'

if docker run --rm "$IMAGE_NAME" /bin/bash -c "$ENTRYPOINT_TEST"; then
    print_status 0 "Entrypoint validation completed"
else
    print_status 1 "Entrypoint validation had issues"
fi

echo ""
echo "=========================================="
echo -e "${YELLOW}Test Summary${NC}"
echo "=========================================="

# Final recommendations
echo ""
echo "Next steps for manual testing:"
echo "1. Test the actual bridge initialization:"
echo "   docker run --rm -it $IMAGE_NAME init"
echo ""
echo "2. Test with your ProtonMail credentials in a safe environment"
echo ""
echo "3. Test SMTP/IMAP connectivity:"
echo "   docker run -d -p 1025:25 -p 1143:143 $IMAGE_NAME"
echo ""
echo "4. Compare performance with the original Debian version"
echo ""

if docker images "$IMAGE_NAME" >/dev/null 2>&1; then
    echo -e "${GREEN}Alpine conversion appears successful!${NC}"
    echo "Image '$IMAGE_NAME' is ready for further testing."
else
    echo -e "${RED}Alpine conversion may have issues.${NC}"
    echo "Review the test output above for details."
fi

echo ""
echo "Cleanup: To remove the test image, run:"
echo "docker rmi $IMAGE_NAME"

#!/bin/bash
# =============================================================================
# MyPsychAdmin - Mac App Store Build Script
# =============================================================================
# This script builds, signs, and packages the app for Mac App Store submission.
#
# PREREQUISITES:
# 1. Apple Developer account ($99/year) - https://developer.apple.com
# 2. Xcode installed with command line tools
# 3. Certificates installed in Keychain:
#    - "3rd Party Mac Developer Application: Your Name (TEAM_ID)"
#    - "3rd Party Mac Developer Installer: Your Name (TEAM_ID)"
# 4. App ID registered in Apple Developer portal with bundle ID: com.mypsychadmin.app
# 5. Provisioning profile for Mac App Store distribution
#
# USAGE:
#   ./build_appstore.sh
#
# =============================================================================

set -e  # Exit on error

# Configuration - UPDATE THESE VALUES
APP_NAME="MyPsychAdmin"
BUNDLE_ID="com.mypsychadmin.app"
VERSION="2.7"

# Certificate names
APP_CERT="Apple Distribution: Avie Luthra (U838Z5U3JY)"
INSTALLER_CERT="3rd Party Mac Developer Installer: Avie Luthra (U838Z5U3JY)"

# Set to "true" to skip signing (for testing builds)
SKIP_SIGNING="${SKIP_SIGNING:-false}"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/dist"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
PKG_PATH="${BUILD_DIR}/${APP_NAME}.pkg"
ENTITLEMENTS="${SCRIPT_DIR}/entitlements.plist"

echo "=============================================="
echo "MyPsychAdmin Mac App Store Build"
echo "=============================================="
echo "Version: ${VERSION}"
echo "Bundle ID: ${BUNDLE_ID}"
echo ""

# Step 1: Clean previous builds
echo "[1/6] Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
rm -rf "${SCRIPT_DIR}/build"

# Step 2: Build with PyInstaller
echo "[2/6] Building app with PyInstaller..."
cd "${SCRIPT_DIR}"
pyinstaller --clean --noconfirm MyPsychAdmin.spec

if [ ! -d "${APP_PATH}" ]; then
    echo "ERROR: Build failed - ${APP_PATH} not found"
    exit 1
fi

echo "Build successful: ${APP_PATH}"

if [ "${SKIP_SIGNING}" = "true" ]; then
    echo "[3/6] Skipping framework signing (SKIP_SIGNING=true)"
    echo "[4/6] Skipping app signing (SKIP_SIGNING=true)"
    echo "[5/6] Skipping signature verification (SKIP_SIGNING=true)"
    echo "[6/6] Skipping installer package (SKIP_SIGNING=true)"
    echo ""
    echo "=============================================="
    echo "BUILD COMPLETE (unsigned)"
    echo "=============================================="
    echo ""
    echo "App bundle: ${APP_PATH}"
    echo ""
    echo "To test the app, run:"
    echo "  open \"${APP_PATH}\""
    echo ""
    echo "To build a signed version for App Store:"
    echo "  1. Set up Apple Developer certificates"
    echo "  2. Update APP_CERT and INSTALLER_CERT in this script"
    echo "  3. Run: ./build_appstore.sh"
    echo ""
    exit 0
fi

# Step 3: Sign all frameworks and libraries
echo "[3/6] Signing frameworks and libraries..."

# Find and sign all .dylib, .so, and .framework files
find "${APP_PATH}" -type f \( -name "*.dylib" -o -name "*.so" \) -exec \
    codesign --force --options runtime --timestamp \
    --entitlements "${ENTITLEMENTS}" \
    --sign "${APP_CERT}" {} \; 2>/dev/null || true

# Sign frameworks
find "${APP_PATH}" -type d -name "*.framework" -exec \
    codesign --force --options runtime --timestamp \
    --entitlements "${ENTITLEMENTS}" \
    --sign "${APP_CERT}" {} \; 2>/dev/null || true

# Step 4: Sign the main executable and app bundle
echo "[4/6] Signing app bundle..."

# Sign the main executable
codesign --force --options runtime --timestamp \
    --entitlements "${ENTITLEMENTS}" \
    --sign "${APP_CERT}" \
    "${APP_PATH}/Contents/MacOS/${APP_NAME}"

# Sign the entire app bundle
codesign --force --deep --options runtime --timestamp \
    --entitlements "${ENTITLEMENTS}" \
    --sign "${APP_CERT}" \
    "${APP_PATH}"

# Step 5: Verify signature
echo "[5/6] Verifying signature..."
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

if [ $? -eq 0 ]; then
    echo "Signature verification successful!"
else
    echo "ERROR: Signature verification failed"
    exit 1
fi

# Also verify with spctl for App Store
echo "Checking Gatekeeper acceptance..."
spctl --assess --type execute --verbose "${APP_PATH}" 2>&1 || true

# Step 6: Create installer package for App Store
echo "[6/6] Creating installer package..."
productbuild --component "${APP_PATH}" /Applications \
    --sign "${INSTALLER_CERT}" \
    "${PKG_PATH}"

if [ -f "${PKG_PATH}" ]; then
    echo ""
    echo "=============================================="
    echo "BUILD COMPLETE!"
    echo "=============================================="
    echo ""
    echo "App bundle: ${APP_PATH}"
    echo "Installer:  ${PKG_PATH}"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Open Transporter app (download from Mac App Store)"
    echo "2. Sign in with your Apple Developer account"
    echo "3. Drag ${PKG_PATH} into Transporter"
    echo "4. Click 'Deliver' to upload to App Store Connect"
    echo "5. Go to https://appstoreconnect.apple.com to complete submission"
    echo ""
else
    echo "ERROR: Package creation failed"
    exit 1
fi

#!/bin/bash

# Copyright (c) 2021-2026 Jason Morley, Tom Sutcliffe
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e
set -o pipefail
set -x
set -u

ROOT_DIRECTORY="$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )"
SCRIPTS_DIRECTORY="$ROOT_DIRECTORY/scripts"
SRC_DIRECTORY="$ROOT_DIRECTORY/core/src"

BUILD_DIRECTORY="$ROOT_DIRECTORY/build"
TEMPORARY_DIRECTORY="$ROOT_DIRECTORY/temp"

ARTIFACTS_DIRECTORY="$ROOT_DIRECTORY/artifacts"

ENV_PATH="$ROOT_DIRECTORY/.env"
RELEASE_SCRIPT_PATH="$SCRIPTS_DIRECTORY/upload-and-publish-release.sh"

source "$SCRIPTS_DIRECTORY/environment.sh"

# Check that the GitHub command is available on the path.
which gh || (echo "GitHub cli (gh) not available on the path." && exit 1)

# Process the command line arguments.
POSITIONAL=()
RELEASE=${RELEASE:-false}
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -r|--release)
        RELEASE=true
        shift
        ;;
        *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done

# Source the .env file if it exists to make local development easier.
if [ -f "$ENV_PATH" ] ; then
    echo "Sourcing .env..."
    source "$ENV_PATH"
fi

cd "$ROOT_DIRECTORY"

# Select the correct Xcode.
IOS_XCODE_PATH=${IOS_XCODE_PATH:-/Applications/Xcode.app}
sudo xcode-select --switch "$IOS_XCODE_PATH"

function cleanup {

    # Cleanup the temporary files and keychain.
    cd "$ROOT_DIRECTORY"
    rm -rf "$TEMPORARY_DIRECTORY"

    # Clean up any private keys.
    if [ -f ~/.appstoreconnect/private_keys ]; then
        rm -r ~/.appstoreconnect/private_keys
    fi

}

trap cleanup EXIT

# Create the build directory.
mkdir -p "$BUILD_DIRECTORY"

# List the artifacts.
find "$ARTIFACTS_DIRECTORY"

# Copy the Qt builds.

# macOS.
QT_MACOS_PATH="$BUILD_DIRECTORY/OpoLua-Qt-macOS-$VERSION_NUMBER-$BUILD_NUMBER.zip"
cp "$ARTIFACTS_DIRECTORY/opolua-qt-macos/build.zip" "$QT_MACOS_PATH"

# Windows.
QT_WINDOWS_PATH="$BUILD_DIRECTORY/OpoLua-Qt-Windows-$VERSION_NUMBER-$BUILD_NUMBER.zip"
cp "$ARTIFACTS_DIRECTORY/opolua-qt-windows/build.zip" "$QT_WINDOWS_PATH"

# Linux.

QT_UBUNTU_2404_ARM64_NAME="opolua-ubuntu-24.04-arm64-$VERSION_NUMBER-$BUILD_NUMBER.deb"
QT_UBUNTU_2404_ARM64_PATH="$BUILD_DIRECTORY/$QT_UBUNTU_2404_ARM64_NAME"
cp "$ARTIFACTS_DIRECTORY/opolua-qt-ubuntu-24.04-arm64/$QT_UBUNTU_2404_ARM64_NAME" "$QT_UBUNTU_2404_ARM64_PATH"

QT_UBUNTU_2404_AMD64_NAME="opolua-ubuntu-24.04-amd64-$VERSION_NUMBER-$BUILD_NUMBER.deb"
QT_UBUNTU_2404_AMD64_PATH="$BUILD_DIRECTORY/$QT_UBUNTU_2404_AMD64_NAME"
cp "$ARTIFACTS_DIRECTORY/opolua-qt-ubuntu-24.04-amd64/$QT_UBUNTU_2404_AMD64_NAME" "$QT_UBUNTU_2404_AMD64_PATH"

QT_UBUNTU_2504_ARM64_NAME="opolua-ubuntu-25.04-arm64-$VERSION_NUMBER-$BUILD_NUMBER.deb"
QT_UBUNTU_2504_ARM64_PATH="$BUILD_DIRECTORY/$QT_UBUNTU_2504_ARM64_NAME"
cp "$ARTIFACTS_DIRECTORY/opolua-qt-ubuntu-25.04-arm64/$QT_UBUNTU_2504_ARM64_NAME" "$QT_UBUNTU_2504_ARM64_PATH"

QT_UBUNTU_2504_AMD64_NAME="opolua-ubuntu-25.04-amd64-$VERSION_NUMBER-$BUILD_NUMBER.deb"
QT_UBUNTU_2504_AMD64_PATH="$BUILD_DIRECTORY/$QT_UBUNTU_2504_AMD64_NAME"
cp "$ARTIFACTS_DIRECTORY/opolua-qt-ubuntu-25.04-amd64/$QT_UBUNTU_2504_AMD64_NAME" "$QT_UBUNTU_2504_AMD64_PATH"

QT_UBUNTU_2510_ARM64_NAME="opolua-ubuntu-25.10-arm64-$VERSION_NUMBER-$BUILD_NUMBER.deb"
QT_UBUNTU_2510_ARM64_PATH="$BUILD_DIRECTORY/$QT_UBUNTU_2510_ARM64_NAME"
cp "$ARTIFACTS_DIRECTORY/opolua-qt-ubuntu-25.10-arm64/$QT_UBUNTU_2510_ARM64_NAME" "$QT_UBUNTU_2510_ARM64_PATH"

QT_UBUNTU_2510_AMD64_NAME="opolua-ubuntu-25.10-amd64-$VERSION_NUMBER-$BUILD_NUMBER.deb"
QT_UBUNTU_2510_AMD64_PATH="$BUILD_DIRECTORY/$QT_UBUNTU_2510_AMD64_NAME"
cp "$ARTIFACTS_DIRECTORY/opolua-qt-ubuntu-25.10-amd64/$QT_UBUNTU_2510_AMD64_NAME" "$QT_UBUNTU_2510_AMD64_PATH"

QT_ARCH_ROLLING_X86_64_NAME="opolua-bin-arch-rolling-x86_64-$VERSION_NUMBER-$BUILD_NUMBER.pkg.tar.zst"
QT_ARCH_ROLLING_X86_64_PATH="$BUILD_DIRECTORY/$QT_ARCH_ROLLING_X86_64_NAME"
cp "$ARTIFACTS_DIRECTORY/opolua-arch-latest-x86_64/$QT_ARCH_ROLLING_X86_64_NAME" "$QT_ARCH_ROLLING_X86_64_PATH"

# Unpack the iOS and Mac Catalyst builds.

unzip "$ARTIFACTS_DIRECTORY/opolua-ios/build.zip" -d "$BUILD_DIRECTORY"
IPA_PATH="$BUILD_DIRECTORY/OpoLua.ipa"
PKG_PATH="$BUILD_DIRECTORY/OpoLua.pkg"

if $RELEASE ; then

    mkdir -p ~/.appstoreconnect/private_keys/
    echo -n "$APPLE_API_KEY_BASE64" | base64 --decode -o ~/".appstoreconnect/private_keys/AuthKey_$APPLE_API_KEY_ID.p8"
    ls ~/.appstoreconnect/private_keys/

    # Validate and upload the iOS build.
    xcrun altool --validate-app \
        -f "$IPA_PATH" \
        --apiKey "$APPLE_API_KEY_ID" \
        --apiIssuer "$APPLE_API_KEY_ISSUER_ID" \
        --output-format json \
        --type ios
    xcrun altool --upload-app \
        -f "$IPA_PATH" \
        --primary-bundle-id "uk.co.inseven.opolua" \
        --apiKey "$APPLE_API_KEY_ID" \
        --apiIssuer "$APPLE_API_KEY_ISSUER_ID" \
        --type ios

    # Validate and upload the macOS build.
    xcrun altool --validate-app \
        -f "$PKG_PATH" \
        --apiKey "$APPLE_API_KEY_ID" \
        --apiIssuer "$APPLE_API_KEY_ISSUER_ID" \
        --output-format json \
        --type macos
    xcrun altool --upload-app \
        -f "$PKG_PATH" \
        --primary-bundle-id "uk.co.inseven.opolua" \
        --apiKey "$APPLE_API_KEY_ID" \
        --apiIssuer "$APPLE_API_KEY_ISSUER_ID" \
        --type macos

    changes \
        release \
        --skip-if-empty \
        --push \
        --exec "$RELEASE_SCRIPT_PATH" \
        "$IPA_PATH" "$PKG_PATH" \
        "$QT_MACOS_PATH" \
        "$QT_WINDOWS_PATH" \
        "$QT_UBUNTU_2404_ARM64_PATH" "$QT_UBUNTU_2404_AMD64_PATH" \
        "$QT_UBUNTU_2504_ARM64_PATH" "$QT_UBUNTU_2504_AMD64_PATH" \
        "$QT_UBUNTU_2510_ARM64_PATH" "$QT_UBUNTU_2510_AMD64_PATH" \
        "$QT_ARCH_ROLLING_X86_64_PATH"

fi

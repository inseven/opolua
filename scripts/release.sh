#!/bin/bash

# Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
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

ENV_PATH="$APP_DIRECTORY/.env"
RELEASE_SCRIPT_PATH="$SCRIPTS_DIRECTORY/upload-and-publish-release.sh"

source "$SCRIPTS_DIRECTORY/environment.sh"

# Check that the GitHub command is available on the path.
which gh || (echo "GitHub cli (gh) not available on the path." && exit 1)

# Process the command line arguments.
POSITIONAL=()
RELEASE=${RELEASE:-false}
UPLOAD_TO_TESTFLIGHT=${UPLOAD_TO_TESTFLIGHT:-false}
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -r|--release)
        RELEASE=true
        shift
        ;;
        -t|--upload-to-testflight)
        UPLOAD_TO_TESTFLIGHT=true
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

# Unpack the existing files.
cd artifacts
unzip opolua-ios/build.zip
unzip opolua-qt-macos/build.zip
unzip opolua-qt-windows/build.zip
ls **/*

if $RELEASE ; then

    mkdir -p ~/.appstoreconnect/private_keys/
    echo -n "$APPLE_API_KEY_BASE64" | base64 --decode -o ~/".appstoreconnect/private_keys/AuthKey_$APPLE_API_KEY_ID.p8"
    ls ~/.appstoreconnect/private_keys/

    changes \
        release \
        --skip-if-empty \
        --pre-release \
        --push \
        --exec "$RELEASE_SCRIPT_PATH" \
        "$IPA_PATH" "$PKG_PATH" "$ZIP_PATH"

fi

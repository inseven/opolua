#!/bin/bash

# Copyright (c) 2021 Jason Morley, Tom Sutcliffe
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

SCRIPTS_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="${SCRIPTS_DIRECTORY}/.."
BUILD_DIRECTORY="${ROOT_DIRECTORY}/build"
TEMPORARY_DIRECTORY="${ROOT_DIRECTORY}/temp"
APP_DIRECTORY="${ROOT_DIRECTORY}"

KEYCHAIN_PATH="${TEMPORARY_DIRECTORY}/temporary.keychain"
ARCHIVE_PATH="${BUILD_DIRECTORY}/Bookmarks.xcarchive"
FASTLANE_ENV_PATH="${APP_DIRECTORY}/fastlane/.env"

source "${SCRIPTS_DIRECTORY}/environment.sh"

# Check that the GitHub command is available on the path.
which gh || (echo "GitHub cli (gh) not available on the path." && exit 1)

# Process the command line arguments.
POSITIONAL=()
ARCHIVE=${ARCHIVE:-false}
TESTFLIGHT_UPLOAD=${TESTFLIGHT_UPLOAD:-false}
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -a|--archive)
        ARCHIVE=true
        shift
        ;;
        -t|--testflight-upload)
        TESTFLIGHT_UPLOAD=true
        shift
        ;;
        *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done

# iPhone to be used for smoke test builds and tests.
# This doesn't specify the OS version to allow the build script to recover from minor build changes.
IPHONE_DESTINATION="platform=iOS Simulator,name=iPhone 13 Pro"

# Generate a random string to secure the local keychain.
export TEMPORARY_KEYCHAIN_PASSWORD=`openssl rand -base64 14`

# Source the Fastlane .env file if it exists to make local development easier.
if [ -f "$FASTLANE_ENV_PATH" ] ; then
    echo "Sourcing .env..."
    source "$FASTLANE_ENV_PATH"
fi

function xcode_project {
    xcodebuild \
        -project OpoLua.xcodeproj "$@"
}

function build_scheme {
    # Disable code signing for the build server.
    xcode_project \
        -scheme "$1" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO "${@:2}"
}

cd "$APP_DIRECTORY"

# Select the correct Xcode.
IOS_XCODE_PATH=${IOS_XCODE_PATH:-/Applications/Xcode.app}
sudo xcode-select --switch "$IOS_XCODE_PATH"

# List the available schemes.
xcode_project -list

# Smoke test builds.

# iOS
build_scheme "OpoLua" clean build \
    -sdk iphonesimulator \
    -destination "$IPHONE_DESTINATION"

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

ROOT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"

SCRIPTS_DIRECTORY="$ROOT_DIRECTORY/scripts"
FPM_OPTIONS_DIRECTORY="$SCRIPTS_DIRECTORY/fpm-options"
SRC_DIRECTORY="$ROOT_DIRECTORY/qt"
BUILD_DIRECTORY="$ROOT_DIRECTORY/qt/build"
INSTALL_DIRECTORY="$BUILD_DIRECTORY/install"
ARTIFACTS_DIRECTORY="$BUILD_DIRECTORY/artifacts"

function fatal {
    echo $1 >&2
    exit 1
}

# Set up the path.
export PATH="$ROOT_DIRECTORY/qt-install/bin:$PATH"

# Determine the version and build number.
VERSION_NUMBER=${VERSION_NUMBER:-0.0.1}
BUILD_NUMBER=${BUILD_NUMBER:-0}

# Build.
mkdir -p "$BUILD_DIRECTORY"
mkdir -p "$ARTIFACTS_DIRECTORY"
cd "$BUILD_DIRECTORY"
qmake6 "VERSION=$VERSION_NUMBER" "BUILD_NUMBER=$BUILD_NUMBER" ..
make
make install INSTALL_ROOT="$INSTALL_DIRECTORY"

# Determine the architecture, OS, and version (used for packaging).
ARCHITECTURE=`dpkg --print-architecture`
source /etc/os-release
if [ "$ID" == "ubuntu" ]; then
    source /etc/lsb-release
    OS_VERSION="$DISTRIB_RELEASE"
else
    fatal "Unsupported Linux distribution ($ID)."
fi

# Package.
PACKAGE_FILENAME="opolua-$ID-$OS_VERSION-$ARCHITECTURE-$VERSION_NUMBER-$BUILD_NUMBER.deb"
fpm \
    -s dir \
    -t deb \
    -p "$PACKAGE_FILENAME" \
    --name "opolua" \
    --version $VERSION_NUMBER \
    --architecture "$ARCHITECTURE" \
    --description "Runtime and viewer for EPOC programs and files." \
    --url "https://opolua.org" \
    --maintainer "Jason Morley <support@opolua.org>" \
    --fpm-options-file "$FPM_OPTIONS_DIRECTORY/$FPM_OPTIONS_FILENAME" \
    --chdir "$INSTALL_DIRECTORY" \
    .
cp "$PACKAGE_FILENAME" "$ARTIFACTS_DIRECTORY"

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
qmake6 "VERSION=$VERSION_NUMBER" "BUILD_NUMBER=$BUILD_NUMBER" ../opolua.pro
make
make install INSTALL_ROOT="$INSTALL_DIRECTORY"

# Package.
source /etc/os-release
DISTRO=$ID
DESCRIPTION="Runtime and viewer for EPOC programs and files."
URL="https://opolua.org"
MAINTAINER="Jason Morley <support@opolua.org>"

case $DISTRO in
    ubuntu|debian)

        ARCHITECTURE=`dpkg --print-architecture`
        source /etc/lsb-release
        OS_VERSION="$DISTRIB_RELEASE"
        PACKAGE_FILENAME="opolua.deb"
        fpm \
            -s dir \
            -t deb \
            -p "$PACKAGE_FILENAME" \
            --name "opolua" \
            --version "${VERSION_NUMBER}~${DISTRIB_CODENAME}${BUILD_NUMBER}" \
            --architecture "$ARCHITECTURE" \
            --description "$DESCRIPTION" \
            --url "$URL" \
            --maintainer "$MAINTAINER" \
            --depends libqt6core6 \
            --depends libqt6gui6 \
            --depends libqt6widgets6 \
            --depends libqt6multimedia6 \
            --depends libqt6core5compat6 \
            --chdir "$INSTALL_DIRECTORY" \
            .
        ;;

    arch|manjaro)

        ARCHITECTURE=`uname -m`
        OS_VERSION="rolling"
        PACKAGE_FILENAME="opolua-bin-$DISTRO-$OS_VERSION-$ARCHITECTURE-$VERSION_NUMBER-$BUILD_NUMBER.pkg.tar.zst"
        fpm \
            -s dir \
            -t pacman \
            -p "$PACKAGE_FILENAME" \
            --name "opolua-bin" \
            --version $VERSION_NUMBER \
            --architecture "$ARCHITECTURE" \
            --description "$DESCRIPTION" \
            --url "$URL" \
            --maintainer "$MAINTAINER" \
            --depends qt6-base \
            --depends qt6-multimedia \
            --depends qt6-5compat \
            --chdir "$INSTALL_DIRECTORY" \
            .
        ;;

    *)
        fatal "Error: Unsupported distribution: $DISTRO."
        ;;
esac

cp "$PACKAGE_FILENAME" "$ARTIFACTS_DIRECTORY"

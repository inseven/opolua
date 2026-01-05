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

ROOT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"

SCRIPTS_DIRECTORY="$ROOT_DIRECTORY/scripts"
BUILD_DIRECTORY="$ROOT_DIRECTORY/qt-build"
INSTALL_DIRECTORY="$ROOT_DIRECTORY/qt-install"

# source "$SCRIPTS_DIRECTORY/environment.sh"

# Clean up the build directory.
if [ -d "$BUILD_DIRECTORY" ] ; then
    rm -r "$BUILD_DIRECTORY"
fi
mkdir -p "$BUILD_DIRECTORY"

# Clean up the install directory.
if [ -d "$INSTALL_DIRECTORY" ] ; then
    rm -r "$INSTALL_DIRECTORY"
fi
mkdir -p "$INSTALL_DIRECTORY"

# Build
# TODO: Minor version.
QT_VERSION=6.8.3
cd "$BUILD_DIRECTORY"
curl -O https://qt.mirror.constant.com/archive/qt/6.8/$QT_VERSION/single/qt-everywhere-src-$QT_VERSION.tar.xz
tar xf qt-everywhere-src-$QT_VERSION.tar.xz
mkdir -p qt-build
cd qt-build

../qt-everywhere-src-$QT_VERSION/configure.bat \
    -prefix "$INSTALL_DIRECTORY" \
    -static \
    -static-runtime \
    -release \
    -optimize-size \
    -opensource \
    -confirm-license \
    -nomake examples \
    -nomake tests \
    -submodules qtmultimedia,qt5compat

cmake --build . --parallel
cmake --install .

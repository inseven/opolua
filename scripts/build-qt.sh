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

SCRIPTS_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="$SCRIPTS_DIRECTORY/.."
SRC_DIRECTORY="$ROOT_DIRECTORY/qt"
BUILD_DIRECTORY="$ROOT_DIRECTORY/qt/build"

source "$SCRIPTS_DIRECTORY/environment.sh"

# Clean up the build directory.
if [ -d "$BUILD_DIRECTORY" ] ; then
    rm -r "$BUILD_DIRECTORY"
fi
mkdir -p "$BUILD_DIRECTORY"

# Determine the version and build number.
VERSION_NUMBER=`changes version`
BUILD_NUMBER=`build-tools generate-build-number`

# Export the version number to be used outside of this action.
echo "changes_version_number=$VERSION_NUMBER" >> "$GITHUB_OUTPUT"
echo "changes_build_number=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"

# Build.
cd "$BUILD_DIRECTORY"
qmake ..
make

# Compress the bundle.
zip "build.zip" "OpoLua Qt.app"

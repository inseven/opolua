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
SRC_DIRECTORY="$ROOT_DIRECTORY/qt"
BUILD_DIRECTORY="$ROOT_DIRECTORY/qt/build"
TEMPORARY_DIRECTORY="${ROOT_DIRECTORY}/temp"

# TODO: Maybe do this in the install step?
export PATH="$ROOT_DIRECTORY/qt-install/bin:$PATH"

# Build.
mkdir -p "$BUILD_DIRECTORY"
cd "$BUILD_DIRECTORY"
qmake ..
make

# Package the app.
# We use `tar` here as `zip` isn't installed on Windows runners.
cd release
tar -a -cf "$BUILD_DIRECTORY/build.zip" opolua.exe

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

function fatal {
    echo $1 >&2
    exit 1
}

# $USER is unbound in GitHub Actions containers. We check this as a way of inferring that we shouldn't be using sudo.
if [ -z ${USER+x} ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Install the per-platform build dependencies.
source /etc/os-release
case $ID in
    ubuntu|debian)
        $SUDO apt-get update -y
        $SUDO apt-get install -y \
            build-essential git \
            qt6-base-dev qt6-base-dev-tools qt6-multimedia-dev qt6-5compat-dev \
            ruby ruby-bundler
        $SUDO gem install --no-user-install fpm
        ;;

    arch|manjaro)
        $SUDO pacman -Syu --noconfirm
        $SUDO pacman -S --noconfirm --needed \
            base-devel git \
            qt6-base qt6-multimedia qt6-5compat \
            ruby
        $SUDO gem install --no-user-install fpm
        ;;

    *)
        fatal "Error: Unsupported distribution: $ID."
        ;;
esac

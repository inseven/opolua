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
CLI_DIRECTORY="$ROOT_DIRECTORY/bin"
WEBSITE_DIRECTORY="$ROOT_DIRECTORY/docs"
CLI_DOCUMENTATION_DIRECTORY="$WEBSITE_DIRECTORY/docs/cli"

source "$SCRIPTS_DIRECTORY/environment.sh"

function generate_command_usage() {
    COMMAND=$1
    # Since OpoLua commands follow the convention of exiting with an error when printing help, we have to temporarily
    # ignore this error.
    mkdir -p "$CLI_DOCUMENTATION_DIRECTORY/$COMMAND"
    set +e
    lua "$CLI_DIRECTORY/$COMMAND.lua" -h > "$CLI_DOCUMENTATION_DIRECTORY/$COMMAND/_help.txt"
    set -e
}

cd "$ROOT_DIRECTORY"

# Determine the version and build number.
VERSION_NUMBER=${VERSION_NUMBER:-0.0.1}
BUILD_NUMBER=${BUILD_NUMBER:-0}

# Install the Jekyll dependencies.
export GEM_HOME="$ROOT_DIRECTORY/.local/ruby"
mkdir -p "$GEM_HOME"
export PATH="$GEM_HOME/bin":$PATH
gem install bundler
cd "$WEBSITE_DIRECTORY"
bundle install

# Build the release notes.
"$SCRIPTS_DIRECTORY/update-release-notes.sh"

# Generate CLI help.
generate_command_usage "compile"
generate_command_usage "dumpaif"
generate_command_usage "dumpdb"
generate_command_usage "dumpdfs"
generate_command_usage "dumpfont"
generate_command_usage "dumpmbm"
generate_command_usage "dumpopo"
generate_command_usage "dumprsc"
generate_command_usage "dumpsis"
generate_command_usage "fscomp"
generate_command_usage "makesis"
generate_command_usage "opltotext"
generate_command_usage "recognize"
generate_command_usage "runopo"


# Build the website.
cd "$WEBSITE_DIRECTORY"
bundle exec jekyll build

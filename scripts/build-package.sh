#!/bin/bash

set -e
set -o pipefail
set -x

ROOT_DIRECTORY="$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )"

cd "$ROOT_DIRECTORY"

xcodebuild -scheme OpoLua -showdestinations

# Build.
xcodebuild -scheme OpoLua -destination "platform=macOS" clean build
xcodebuild -scheme OpoLua -destination "$DEFAULT_IPHONE_DESTINATION" clean build

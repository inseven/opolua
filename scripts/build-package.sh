#!/bin/bash

set -e
set -o pipefail
set -x

ROOT_DIRECTORY="$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )"

cd "$ROOT_DIRECTORY"

xcodebuild -scheme OpoLuaCore -showdestinations

# Build.
xcodebuild -scheme OpoLuaCore -destination "platform=macOS" clean build
xcodebuild -scheme OpoLuaCore -destination "$DEFAULT_IPHONE_DESTINATION" clean build

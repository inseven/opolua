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

ROOT_DIRECTORY="$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )"
SCREENSHOTS_DIRECTORY="$ROOT_DIRECTORY/screenshots/app-store/2.0.0/mac"

function screenshot_light {
    magick \
        -size 2880x1800 \
        gradient:'rgb(132, 203, 204)-rgb(132, 203, 204)' \
        "$1" \
        -gravity Center \
        -geometry +0+36 \
        -composite "$2"
}

screenshot_light "$SCREENSHOTS_DIRECTORY/1-files.png" "$SCREENSHOTS_DIRECTORY/app-store-1-files.png"
screenshot_light "$SCREENSHOTS_DIRECTORY/2-image.png" "$SCREENSHOTS_DIRECTORY/app-store-2-image.png"
screenshot_light "$SCREENSHOTS_DIRECTORY/3-sound.png" "$SCREENSHOTS_DIRECTORY/app-store-3-sound.png"
screenshot_light "$SCREENSHOTS_DIRECTORY/4-scripts.png" "$SCREENSHOTS_DIRECTORY/app-store-4-scripts.png"
screenshot_light "$SCREENSHOTS_DIRECTORY/5-welcome.png" "$SCREENSHOTS_DIRECTORY/app-store-5-welcome.png"
screenshot_light "$SCREENSHOTS_DIRECTORY/6-programs.png" "$SCREENSHOTS_DIRECTORY/app-store-6-programs.png"

#!/bin/bash

set -e
set -o pipefail
set -x
set -u

# cd /tmp
curl -O https://qt.mirror.constant.com/archive/qt/6.9/6.9.1/single/qt-everywhere-src-6.9.1.tar.xz
tar xf qt-everywhere-src-6.9.1.tar.xz
mkdir -p qt-build
# cd qt-build
cd qt-build
/tmp/qt-everywhere-src-6.9.1/configure
./configure
cmake --build . --parallel

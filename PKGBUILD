# Maintainer: Jason Morley <support@opolua.org>
pkgname=opolua-git
pkgver=2.1.4
pkgrel=1
pkgdesc="Runtime and viewer for EPOC programs and files"
arch=(x86_64
      aarch64)
url="https://github.com/inseven/opolua"
license=(MIT
         GPL-2.0-or-later)
depends=(qt6-base
         qt6-multimedia
         qt6-5compat)
makedepends=(git
             make
             gcc)

source=(
    "git+https://github.com/inseven/opolua.git#commit=6358d23acbf0e58511fec92d6f41dd97dd98b293"
    "git+https://github.com/tomsci/LuaSwift.git"
    "git+https://github.com/lua/lua.git"
    "git+https://github.com/inseven/diligence.git"
    "git+https://github.com/jbmorley/changes.git"
    "git+https://github.com/jbmorley/build-tools.git"
)

sha256sums=(
    "SKIP"
    "SKIP"
    "SKIP"
    "SKIP"
    "SKIP"
    "SKIP"
)

prepare() {

    cd "$srcdir/opolua"
    git submodule init
    git config submodule.LuaSwift.url "$srcdir/LuaSwift"
    git config submodule.diligence.url "$srcdir/diligence"
    git config submodule.scripts/changes.url "$srcdir/changes"
    git config submodule.scripts/build-tools.url "$srcdir/build-tools"
    git -c protocol.file.allow=always submodule update --recursive

    cd "$srcdir/opolua/dependencies/LuaSwift"
    git submodule init
    git config submodule.Sources/CLua/lua.url "$srcdir/lua"
    git -c protocol.file.allow=always submodule update

}

build() {

    cd "$srcdir/opolua/qt"
    qmake6
    make

}

package() {

    cd "$srcdir/opolua/qt"
    make install INSTALL_ROOT="$pkgdir"

}

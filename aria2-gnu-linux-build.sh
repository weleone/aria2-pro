#!/usr/bin/env bash
#
# Copyright (c) 2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Aria2-Pro-Core
# File name: aria2-gnu-linux-build.sh
# Description: Aria2 Build on the target platforms
# System Required: Debian & Ubuntu & Fedora & Arch Linux
# Version: 1.6
#

set -e
[ $EUID != 0 ] && SUDO=sudo
$SUDO echo
SCRIPT_DIR=$(dirname $(readlink -f $0))

## CONFIG ##
ARCH="$(uname -m)"
# MODIFIED (2026-10-02): OpenSSL 1.1.1 的 linux-elf target 在 3.x 已不可用，
# 按实际架构选择 Configure target（OpenSSL 3.x 均有效）
case "$(uname -m)" in
x86_64) OPENSSL_ARCH="linux-x86_64" ;;
aarch64) OPENSSL_ARCH="linux-aarch64" ;;
i*86) OPENSSL_ARCH="linux-x86" ;;
arm*) OPENSSL_ARCH="linux-generic32" ;;
*) OPENSSL_ARCH="linux-generic64" ;;
esac
BUILD_DIR="/tmp"
ARIA2_CODE_DIR="$BUILD_DIR/aria2"
OUTPUT_DIR="$HOME/output"
PREFIX="$BUILD_DIR/aria2-build-libs"
ARIA2_PREFIX="/usr/local"
export CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export LD_LIBRARY_PATH="$PREFIX/lib"
# 自建 OpenSSL 经 LD_LIBRARY_PATH 会污染系统 curl，下载时隔离
curl() { (unset LD_LIBRARY_PATH; command curl "$@"); }
export CC="gcc"
export CXX="g++"
export STRIP="strip"
export RANLIB="ranlib"
export AR="ar"
export LD="ld"

## DEPENDENCES ##
source $SCRIPT_DIR/dependences

## TOOLCHAIN ##
source $SCRIPT_DIR/snippet/target-toolchain

TOOLCHAIN() {
    if [ -x "$(command -v apt-get)" ]; then
        DEBIAN_INSTALL
    elif [ -x "$(command -v dnf)" ]; then
        FEDORA_INSTALL
    elif [ -x "$(command -v pacman)" ]; then
        ARCH_INSTALL
    else
        echo -e "This operating system is not supported !"
        exit 1
    fi
}

## BUILD ##
source $SCRIPT_DIR/snippet/target-build

## ARIA2 COEDE ##
source $SCRIPT_DIR/snippet/aria2-code

## ARIA2 BIN ##
source $SCRIPT_DIR/snippet/aria2-bin

## CLEAN ##
source $SCRIPT_DIR/snippet/clean

## BUILD PROCESS ##
TOOLCHAIN
ZLIB_BUILD
EXPAT_BUILD
C_ARES_BUILD
OPENSSL_BUILD
SQLITE3_BUILD
LIBSSH2_BUILD
#JEMALLOC_BUILD
ARIA2_BUILD
#ARIA2_BIN
ARIA2_PACKAGE
#ARIA2_INSTALL
CLEANUP_ALL

echo "finished!"

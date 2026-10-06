#!/bin/bash
# aria2 1.37.0 一键构建（amd64）
# 用法：在本目录执行 ./build.sh
set -e
cd "$(dirname "$0")"
docker build \
  --build-arg BUILDER_IMAGE=debian:12 \
  --build-arg BUILD_SCRIPT=aria2-gnu-linux-build-amd64.sh \
  -o ./output .
echo ""
echo "构建完成，产物在 ./output/aria2-static-linux-x86_64.tar.gz"

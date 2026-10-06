# Aria2-Pro-Core 构建用 Dockerfile
# 修改点（2026-10-02）：默认构建镜像从 debian:10 改为 debian:12
# （debian:10 已 EOL，apt 源被归档会导致构建失败）
ARG BUILDER_IMAGE=debian:12

FROM $BUILDER_IMAGE AS builder

WORKDIR /P3TERX/aria2-builder

COPY . .

ENV DEBIAN_FRONTEND=noninteractive

ARG BUILD_SCRIPT=aria2-gnu-linux-build.sh

RUN bash $BUILD_SCRIPT

FROM scratch

COPY --from=builder /root/output /

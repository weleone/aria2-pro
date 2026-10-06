# Aria2 1.37.0 构建方案（基于 P3TERX/Aria2-Pro-Core）

目标：构建带 P3TERX 补丁的 aria2 **1.37.0** 静态二进制，替代官方停更在
1.36.0（2021）的版本，再接到 Aria2-Pro-Docker 里使用。

## 文件清单

| 文件 | 说明 |
|---|---|
| `dependences` | 依赖版本已升级（zlib 1.3.1 / expat 2.8.5 / c-ares 1.34.8 / **OpenSSL 3.0.22** / sqlite 3.53.4 / libssh2 1.11.1），下载地址已逐个验证有效 |
| `snippet/aria2-code` | 源码锁定为官方 `release-1.37.0` tarball，不再跟踪 git master |
| `patch/0001~0003` | 3 个有效 patch（0001/0002/0003 已实测可干净应用到 1.37.0） |
| `aria2-gnu-linux-build.sh` | 通用构建脚本，修复 OpenSSL 3.x 的 Configure target（原 `linux-elf` 已失效） |
| `snippet/target-build` `snippet/aria2-code` | 下载改成“先落盘再解压”+ curl 5 次重试，防网络抖动导致构建中断；curl 加 --fail，HTTP 错误直接失败不再让 tar 解错误页面 |
|  | sqlite 3.53.4 已删除 ，改用  |
| `aria2-gnu-linux-build-amd64.sh` | amd64 专用脚本（OpenSSL target 已是 `linux-x86_64`，3.x 可用，原样保留） |
| `Dockerfile` | 构建镜像默认改为 `debian:12`（原 `debian:10` 已 EOL，apt 源归档会构建失败） |
| `aria2-install-fork.sh` | 安装脚本，改好里面的 `GH_API_URL` 指向你的 fork 即可用 |
| `PATCH-NOTES.md` | patch 实测验证报告（含 0004 废弃原因） |
| `snippet/target-build` `target-toolchain` `aria2-bin` `clean` | 原样保留 |

## 步骤一：Fork 并覆盖文件

1. Fork `P3TERX/Aria2-Pro-Core` 到你自己的 GitHub 账号。
2. 把本目录的文件覆盖到 fork 仓库对应位置：
   - `dependences` → 仓库根目录
   - `snippet/aria2-code` → `snippet/aria2-code`
   - `patch/` → 删除原有的 `0004-*.patch`，用本目录的 3 个 patch 替换
   - `aria2-gnu-linux-build.sh` → 仓库根目录
   - `Dockerfile` → 仓库根目录
3. commit 并 push。

## 步骤二：构建（先只做 amd64）

在有 Docker 的 x86_64 机器上：

```bash
git clone <你的fork地址> && cd Aria2-Pro-Core
docker build \
  --build-arg BUILDER_IMAGE=debian:12 \
  --build-arg BUILD_SCRIPT=aria2-gnu-linux-build-amd64.sh \
  -o ./output .
```

构建约 10~20 分钟（编译 OpenSSL 等依赖）。产物在 `./output/`：
`aria2-static-linux-x86_64.tar.gz`。

> 也可以直接在 Debian/Ubuntu 机器上跑：`sudo bash aria2-gnu-linux-build-amd64.sh`，
> 产物在 `~/output/`。arm64/armhf/i386 用对应的 cross-build 脚本（交叉工具链
> 年久，**先保证 amd64 成功**再折腾）。

## 步骤三：验证二进制

```bash
tar xzf output/aria2-static-linux-x86_64.tar.gz
./aria2c -v
# 期望看到：aria2 version 1.37.0，且特性列表含 openssl 3.0.22

# 验证 P3TERX 自定义选项还在：
./aria2c --help | grep -E "retry-on-40|max-connection-per-server"
# 验证 1.37 原生选项：
./aria2c --help | grep "no-want-digest-header"
```

## 步骤四：发 Release

在你的 fork 仓库创建一个 release，例如 tag `1.37.0_2026.10.02`，
把各架构的 `aria2-static-linux-*.tar.gz` 传上去。**这个 release 必须设为
latest**（安装脚本取的是 latest）。

## 步骤五：接到 Aria2-Pro-Docker

1. 把 `aria2-install-fork.sh` 里的 `GH_API_URL` 改成你的 fork 地址，
   放到 fork 仓库根目录（或 gist），得到直链 URL。
2. 修改 `Aria2-Pro-Docker` 的 Dockerfile，把原来这行：

```dockerfile
RUN apk add --no-cache jq findutils && \
    curl -fsSL git.io/aria2c.sh | bash && \
    rm -rf /var/cache/apk/* /tmp/*
```

换成：

```dockerfile
RUN apk add --no-cache jq findutils && \
    curl -fsSL https://raw.githubusercontent.com/<你的用户名>/Aria2-Pro-Core/master/aria2-install-fork.sh | bash && \
    rm -rf /var/cache/apk/* /tmp/*
```

3. 重新 `docker build` 即得到 aria2 1.37.0 的镜像。

## 配置变更提醒

- `aria2.conf` 里如果启用了 `http-want-digest`（官方模板默认注释掉），
  请改为 `no-want-digest-header=true`（语义取反，详见 PATCH-NOTES.md）。
- 其余配置项 1.36 → 1.37 无破坏性变更，可直接沿用。

## 风险提示

- 本方案在本机**未实际执行完整编译**（沙盒无 Docker），patch 应用已实测，
  但完整构建请在你的机器上按步骤二验证。
- cross 构建脚本依赖的老版本交叉工具链可能下载失效，amd64 优先。
- OpenSSL 从 1.1.1（已 EOL）升到 3.0.22 是本次升级的重要安全收益。

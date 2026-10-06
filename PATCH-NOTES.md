# Patch 验证报告（实测，2026-10-02）

测试方法：在 aria2 官方 `release-1.37.0` tag 的干净源码上执行
`git apply --check` 逐个验证 `patch/` 下的 patch。

| Patch | 文件 | 结果 | 说明 |
|---|---|---|---|
| 0001 解锁 connection-per-server 限制 | `src/OptionHandlerFactory.cc` | ✅ 干净应用 | 无需修改 |
| 0002 低速自动重试 | `src/SocketBuffer.cc` `src/SocketCore.cc` | ✅ 应用（offset 7 行） | 正常现象，无需修改 |
| 0003 HTTP 4xx 自动重试选项 | `src/prefs.h` `src/usage_text.h` 等 | ✅ 应用（offset -1/-13 行） | 正常现象，无需修改 |
| 0004 禁用 Want-Digest 选项 | — | ❌ **已废弃，不打** | 见下 |

## 0004 为什么废弃

aria2 1.37.0 上游**原生**加入了等价功能：

```
src/prefs.cc:433:  PrefPtr PREF_NO_WANT_DIGEST_HEADER = makePref("no-want-digest-header");
src/HttpRequestCommand.cc:102: httpRequest->setNoWantDigest(option->getAsBool(PREF_NO_WANT_DIGEST_HEADER));
```

即 `--no-want-digest-header[=true|false]`。P3TERX 的 0004 patch 提供的是
`--http-want-digest`（语义相反），在 1.37.0 上 `src/prefs.h` 的 hunk 已无法应用，
且功能已被官方实现，因此本方案中**直接删除 0004，不做 rebase**。

⚠️ 配置文件注意：如果你的 `aria2.conf` 里启用了 `http-want-digest`（P3TERX
`aria2.conf` 模板里默认是注释掉的），升级到 1.37.0 后请改为
`no-want-digest-header=true`（注意语义取反：原来 `http-want-digest=false`
等价于现在 `no-want-digest-header=true`）。

## 2026-10-03：OpenSSL legacy provider 根因修复

**现象**：aria2c 启动报 `OSSL_PROVIDER_load 'legacy' failed`。

**根因**：`ARIA2_STATIC=yes` 会让 aria2 的 configure 加上 libtool `-all-static`，
最终二进制是**完全静态链接**的，没有动态符号表。之前尝试的
`-Wl,--export-dynamic` 对完全静态二进制是静默无效的，所以 legacy.so
dlopen 后永远无法从主程序解析 libcrypto 符号。

**修复**：OpenSSL Configure 改为 `no-shared no-module`。
`no-module` 会把 legacy/default provider 直接编译进 libcrypto.a
（STATIC_LEGACY），`OSSL_PROVIDER_load(NULL, "legacy")` 在运行时找到的是
内建 provider，不再需要外部 `ossl-modules/legacy.so`，也不需要设置
`OPENSSL_MODULES`。此方案已被多个静态构建项目验证。

**连带清理**：
- 移除 ARIA2_BUILD 中的 `--export-dynamic`（无效）。
- 移除 ARIA2_PACKAGE 中的 ossl-modules 复制逻辑。
- Dockerfile（构建用）无需修改；运行时 Dockerfile 不需要
  `COPY ossl-modules` 和 `ENV OPENSSL_MODULES`（如已加请删除）。

# 预编译的 `tc` 二进制

这些 **不是本项目的代码**，而是从 [Alpine Linux](https://alpinelinux.org/) 的
`iproute2-tc` 包里提取的 `iproute2` 发行版二进制，用于解决「OpenWrt 固件里没有 `tc` 命令」的问题。

本项目只做「提取 + 分发」，未作任何代码修改。

## 来源

| 项目 | 值 |
|---|---|
| 上游 | [iproute2](https://git.kernel.org/pub/scm/network/iproute2/iproute2.git/) |
| 发行包 | Alpine Linux `iproute2-tc-6.9.0-r0`（`v3.20/main`) |
| 下载地址 | `https://dl-cdn.alpinelinux.org/alpine/v3.20/main/<arch>/iproute2-tc-6.9.0-r0.apk` |
| 许可证 | **GPL-2.0**（与本项目 MIT 不同，见下） |

## 架构对照

| 目录 | Alpine arch | `uname -m` | OpenWrt arch | ELF |
|---|---|---|---|---|
| `aarch64/` | aarch64 | `aarch64` | `aarch64_cortex-a53` | 64-bit ARM |
| `armv7/` | armv7 | `armv7l` | `arm_cortex-a7` 等 | 32-bit ARM |
| `x86_64/` | x86_64 | `x86_64` | `x86_64` | 64-bit x86 |
| `x86/` | x86 | `i386` / `i686` | `i386_pentium4` 等 | 32-bit x86 |

## 校验值

```
f3a8adee02bfcf9d0d729ae07f775d28b9eecc5356262d86dee520bf18d87037  aarch64/tc   551,520 B
602eed13e824a54cdc13942089cfdfae2fe2ce14dd1f8a3b224c42351d931f57  armv7/tc     376,944 B
9a4c625cce53ef1048f476b6e9e46a6c9ec2b991fce3159f5c81c2f382bb8c7a  x86_64/tc    490,888 B
e900f97942332e09dc6bff279cf6e8805431f2e347f62a5cf4629a99d8ac570e  x86/tc       487,956 B
```

核验：

```sh
sha256sum -c <<'EOF'
f3a8adee02bfcf9d0d729ae07f775d28b9eecc5356262d86dee520bf18d87037  aarch64/tc
602eed13e824a54cdc13942089cfdfae2fe2ce14dd1f8a3b224c42351d931f57  armv7/tc
9a4c625cce53ef1048f476b6e9e46a6c9ec2b991fce3159f5c81c2f382bb8c7a  x86_64/tc
e900f97942332e09dc6bff279cf6e8805431f2e347f62a5cf4629a99d8ac570e  x86/tc
EOF
```

## 依赖

`tc` 是动态链接的（Alpine 用 musl，OpenWrt 也是 musl，可直接运行）。运行时需要：

- `libmnl.so.0`
- `libelf.so.1`（> 6.0 版本的 iproute2 需要）
- `libbpf.so.1`（部分构建需要）

OpenWrt 一般自带前两个；缺的话 `ldd /usr/bin/tc` 会列出未满足项。

`dist/` 目录是 `tc` 的链路层参数表（`tc qdisc ... linklayer ethernet` 之类会用到），
需要放到 `/usr/lib/tc/`。

## 已验证

- **aarch64**：在 iStoreOS 2.02（Airoha AN7581，内核 6.18）上实测可用 ✅
- armv7 / x86_64 / x86：同源同版本，ELF 头已校验，但**未做实机验证**

## 许可证（重要）

`iproute2` 采用 **GPL-2.0**，与本项目的 MIT 许可证**不同**：

- 本仓库根目录的 `LICENSE`（MIT）**只覆盖本项目自己写的脚本、JS、配置**
- `prebuilt/tc/` 下的二进制遵循 **GPL-2.0**
- 对应源码可从上游获取：<https://www.kernel.org/pub/linux/utils/net/iproute2/>
- 或 Alpine 的包源码：<https://git.alpinelinux.org/aports/tree/main/iproute2>

如需完全遵守 GPL-2.0 的分发要求，请自行确认源码可得性（本项目已在此处给出上游地址）。

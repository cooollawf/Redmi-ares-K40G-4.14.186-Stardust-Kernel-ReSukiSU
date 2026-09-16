# Stardust Kernel — Redmi K40 Gaming (ares)

适用于 Redmi K40 游戏增强版 / POCO F3 GT 的自定义内核，基于 Linux 4.14.186 LTS（MIUI 14.0.4.0 / TKJCNXM），集成 ReSukiSU 与 SUSFS v2.3.0。

[![Kernel](https://img.shields.io/badge/Kernel-4.14.186-blue)]()
[![Android](https://img.shields.io/badge/Android-13-green)]()
[![SoC](https://img.shields.io/badge/SoC-MT6893-orange)]()
[![License](https://img.shields.io/badge/License-GPL--2.0-red)]()

> [!WARNING]
> 这个内核很可能只兼容 MIUI 14.0.4.0（TKJCNXM）。
> 其他版本未测试，使用风险自负。

> [!CAUTION]
> **关于更新 ReSukiSU Kernel 侧**
>
> 本项目的 ReSukiSU 为 **non-GKI（4.14）做了大量硬修改**，包括但不限于：
> - `Kbuild` 中绕过 submodule 检查
> - `selinux/rules.c` 中禁用策略注入
> - `feature/selinux_hide.c` 中禁用钩子
> - 4.14 专用的 `ksu_dup_policydb` / `memcpy` 兼容逻辑
> - 还有一系列为了兼容性变更下做的修改和妥协
>
> **在不确定你有十分把握的情况下，请尽量不要直接替换或更新 ReSukiSU Kernel 侧的源码，也不要激活我们源码中从未激活的钩子。**
> 直接更新上游 ReSukiSU 会覆盖这些修改，导致内核无法启动或其他意料之外的问题。
>
> 如需更新，请先阅读本项目 `drivers/kernelsu/` 下的所有改动，并逐个合并。

---

## 来源声明 (Derivative Work Notice)

本项目是一个基于 **GPL-2.0** 许可的衍生作品。来源链条如下：

- **直接上游**：[WangCghy/KernelSU_ares](https://github.com/WangCghy/KernelSU_ares)（在 Tkpointz 基础上集成 KernelSU，本项目在此基础上修改）
- **二级上游**：[Tkpointz/android_kernel_aresin](https://github.com/Tkpointz/android_kernel_aresin)
- **原始来源**：小米官方 `ares-r-oss` 内核源码

### 本项目的修改 (Changes by Stardust Kernel)

- **Root 方案替换**：将 KernelSU 替换为 **ReSukiSU**
- **隐藏方案集成**：集成 **SUSFS v2.3.0**
- **系统适配**：适配 Android 13 / MIUI 14.0.4.0，修复 4.14 non-GKI 上的 SELinux / AIDL 相关问题
- **构建流程**：重写 `build.sh` 和 `build-inc.sh`，移除硬编码路径

> 注：上游 `WangCghy/KernelSU_ares` 使用 git submodule 管理 KernelSU。
> 本项目将 KernelSU 作为普通目录内联，并替换为 ReSukiSU。

---

## 简介

| 项目 | 值 |
|---|---|
| **设备** | Redmi K40 游戏增强版 (ares) / POCO F3 GT (aresin) |
| **SoC** | MediaTek Dimensity 1200 (MT6893) |
| **内核** | Linux 4.14.186 LTS (non-GKI) |
| **Android** | 13 |
| **Root** | ReSukiSU |
| **隐藏** | SUSFS v2.3.0 |
| **工具链** | clang-18 (neutron) |
| **编译目标** | `Image.gz-dtb` |

---

## 特性

- 基于小米官方 `ares-r-oss` 内核源码
- 集成 **ReSukiSU**（KernelSU 的活跃分支），支持 `ADB Root`、`susfs` 等扩展功能
- 集成 **SUSFS v2.3.0**，提供路径隐藏、cmdline 伪造、uname 伪装等 Root 隐藏能力
- 修复 4.14 non-GKI 上的 **AIDL / SurfaceFlinger 注册问题**
- 重写 `build.sh` 和 `build-inc.sh`，移除对原脚本作者硬编码路径的依赖

---

## 编译

### 前置依赖

- **clang-18**（neutron 工具链）
- **aarch64-linux-gnu-gcc**、**arm-linux-gnueabi-gcc**

```bash
sudo apt install gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi
```

### 工具链路径

默认从仓库上一级的 `clang-18_neutron/` 读取，也可以通过 `TOOLCHAIN_DIR` 环境变量指定：

```bash
export TOOLCHAIN_DIR=/path/to/clang-18_neutron
```

### 全量编译

```bash
./build.sh
```

### 增量编译（保留 `out/` 与 ccache）

```bash
./build-inc.sh
```

> **注意**：改了头文件、`defconfig`、`Kconfig` 或 `KernelSU/` 下的源码后，**必须用 `./build.sh` 全量重编**，不要用增量脚本，否则会有 `.o` 文件漏编的风险。

### 产物

```
out/arch/arm64/boot/Image.gz-dtb
```

---

## 来源与致谢

本项目的上游链条：

1. **小米官方 `ares-r-oss`** — Redmi K40 Gaming / POCO F3 GT 的官方 Linux 4.14.186 内核源码
2. **[Tkpointz/android_kernel_aresin](https://github.com/Tkpointz/android_kernel_aresin)** — 社区维护的 ares 内核基线
3. **[WangCghy/KernelSU_ares](https://github.com/WangCghy/KernelSU_ares)** — 在 Tkpointz 基础上集成 KernelSU
4. **本项目** — 在 WangCghy 基础上替换为 ReSukiSU，并集成 SUSFS
5. **[ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)** — Root 方案
6. **[simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)** — Root 隐藏方案

感谢以上项目的作者与贡献者。

---

## 已知问题

- 本项目早期尝试过 SELinux Enforcing，但 4.14 non-GKI 上动态策略注入不稳定，最终采用 **Permissive + SUSFS 隐藏**方案
- 在 permissive 模式下，KernelSU 会主动关闭 seccomp（设计行为，非 bug）
- 4.14 non-GKI 上部分 MTK 驱动与 clang-18 存在兼容性警告，已通过 `KCFLAGS="-Wno-error"` 压制

---

## 许可证

本项目基于 Linux 内核源码，遵循 **GPL-2.0** 许可证。详见 [LICENSE](LICENSE)。

---

## 关于

Stardust Kernel 由来自中国黑龙江的独立开发者维护。
在东北，自由软件和开源硬件的火种一直存在，只是不常被看见。

---

# Stardust Kernel — Redmi K40 Gaming (ares)

Custom Linux 4.14.186 LTS kernel for the Redmi K40 Gaming / POCO F3 GT, with ReSukiSU and SUSFS v2.3.0 integrated.

[![Kernel](https://img.shields.io/badge/Kernel-4.14.186-blue)]()
[![Android](https://img.shields.io/badge/Android-13-green)]()
[![SoC](https://img.shields.io/badge/SoC-MT6893-orange)]()
[![License](https://img.shields.io/badge/License-GPL--2.0-red)]()

> [!WARNING]
> This kernel is most likely only compatible with MIUI 14.0.4.0 (TKJCNXM).
> Other versions have not been tested. Use at your own risk.

> [!CAUTION]
> **About updating ReSukiSU Kernel side**
>
> The ReSukiSU in this project has **extensive hard modifications for non-GKI (4.14)**, including but not limited to:
> - Bypassing submodule check in `Kbuild`
> - Disabling policy injection in `selinux/rules.c`
> - Disabling hooks in `feature/selinux_hide.c`
> - 4.14-specific `ksu_dup_policydb` / `memcpy` compatibility logic
> - A series of other modifications and compromises made for compatibility
>
> **Unless you are fully confident, please do NOT directly replace or update the ReSukiSU Kernel source, and do NOT enable hooks that were never enabled in our source.**
> Directly updating upstream ReSukiSU will overwrite these modifications and may cause the kernel to fail to boot or produce other unexpected issues.
>
> If you need to update, please first read all changes under `drivers/kernelsu/` in this project and merge them one by one.
---

## Derivative Work Notice

This project is a derivative work licensed under **GPL-2.0**. The upstream chain is:

- **Direct upstream**: [WangCghy/KernelSU_ares](https://github.com/WangCghy/KernelSU_ares) (KernelSU integration on top of Tkpointz; this project modifies it)
- **Secondary upstream**: [Tkpointz/android_kernel_aresin](https://github.com/Tkpointz/android_kernel_aresin)
- **Original source**: Xiaomi's official `ares-r-oss` kernel source

### Changes by Stardust Kernel

- **Root replacement**: KernelSU replaced with **ReSukiSU**
- **Hiding integration**: **SUSFS v2.3.0** integrated
- **System adaptation**: Adapted for Android 13 / MIUI 14.0.4.0; fixed SELinux / AIDL issues on 4.14 non-GKI
- **Build flow**: `build.sh` and `build-inc.sh` rewritten, hardcoded paths removed

> Note: The direct upstream `WangCghy/KernelSU_ares` manages KernelSU as a git submodule.
> This project inlines KernelSU as a regular directory and replaces it with ReSukiSU.

---

## Overview

| Item | Value |
|---|---|
| **Device** | Redmi K40 Gaming (ares) / POCO F3 GT (aresin) |
| **SoC** | MediaTek Dimensity 1200 (MT6893) |
| **Kernel** | Linux 4.14.186 LTS (non-GKI) |
| **Android** | 13 |
| **Root** | ReSukiSU |
| **Hide** | SUSFS v2.3.0 |
| **Toolchain** | clang-18 (neutron) |
| **Build target** | `Image.gz-dtb` |

---

## Features

- Based on Xiaomi's official `ares-r-oss` kernel source
- Integrated **ReSukiSU** (active KernelSU fork), with `ADB Root` and `susfs` support
- Integrated **SUSFS v2.3.0** for path hiding, cmdline spoofing and uname spoofing
- Fixed AIDL / SurfaceFlinger registration issues on 4.14 non-GKI
- Rewritten `build.sh` and `build-inc.sh`, no hardcoded paths from the original author

---

## Build

### Prerequisites

- **clang-18** (neutron toolchain)
- **aarch64-linux-gnu-gcc**, **arm-linux-gnueabi-gcc**

```bash
sudo apt install gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi
```

### Toolchain path

By default, the script looks for `clang-18_neutron/` one level above the repo.
You can also set `TOOLCHAIN_DIR` explicitly:

```bash
export TOOLCHAIN_DIR=/path/to/clang-18_neutron
```

### Full build

```bash
./build.sh
```

### Incremental build (keeps `out/` and ccache)

```bash
./build-inc.sh
```

> **Note**: After modifying headers, `defconfig`, `Kconfig`, or anything under `KernelSU/`,
> you **must** use `./build.sh` for a full rebuild. Incremental build may miss stale `.o` files.

### Output

```
out/arch/arm64/boot/Image.gz-dtb
```

---

## Credits

Upstream chain:

1. **Xiaomi `ares-r-oss`** — official Linux 4.14.186 kernel source
2. **[Tkpointz/android_kernel_aresin](https://github.com/Tkpointz/android_kernel_aresin)** — community-maintained ares kernel baseline
3. **[WangCghy/KernelSU_ares](https://github.com/WangCghy/KernelSU_ares)** — KernelSU integration on top of Tkpointz
4. **This project** — ReSukiSU replacement + SUSFS integration
5. **[ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)** — root solution
6. **[simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)** — root hiding

Thanks to all authors and contributors above.

---

## Known Issues

- Early builds attempted SELinux Enforcing, but dynamic policy injection is unstable on 4.14 non-GKI; the project ultimately uses **Permissive + SUSFS hiding**
- On permissive mode, KernelSU disables seccomp by design
- Some MTK drivers on 4.14 non-GKI emit clang-18 compatibility warnings; suppressed via `KCFLAGS="-Wno-error"`

---

## License

This project is based on the Linux kernel and is licensed under **GPL-2.0**. See [LICENSE](LICENSE).

---

## About

Stardust Kernel is maintained by an independent developer from Heilongjiang, China.
In Northeast China, the spark of free software and open hardware has always been there — just not often seen.
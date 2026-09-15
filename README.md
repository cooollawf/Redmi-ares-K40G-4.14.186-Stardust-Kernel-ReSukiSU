# Stardust Kernel — Redmi K40 Gaming (ares)

适用于 Redmi K40 游戏增强版 / POCO F3 GT 的自定义内核，基于 Linux 4.14.186 LTS（MIUI14.0.4.0(TKJCNXM)），
集成 ReSukiSU 与 SUSFS v2.3.0。

[![Kernel](https://img.shields.io/badge/Kernel-4.14.186-blue)]()
[![Android](https://img.shields.io/badge/Android-13-green)]()
[![SoC](https://img.shields.io/badge/SoC-MT6893-orange)]()
[![License](https://img.shields.io/badge/License-GPL--2.0-red)]()

> [!WARNING]
> 这个内核很可能只兼容 MIUI 14.0.4.0（TKJCNXM）。
> 其他版本未测试，使用风险自负。
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
- **SELinux 保持 Enforcing**，不依赖 permissive 模式
- 重写 `build.sh`，移除对原脚本作者硬编码路径的依赖

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
3. **[ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)** — Root 方案，KernelSU 的活跃分支
4. **[simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)** — Root 隐藏方案

感谢以上项目的作者与贡献者。

---

## 已知问题

- SELinux 必须保持 **Enforcing**，否则 SUSFS 的隐藏能力会打折扣
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

Custom Linux 4.14.186 LTS kernel for the Redmi K40 Gaming / POCO F3 GT,
with ReSukiSU and SUSFS v2.3.0 integrated.

[![Kernel](https://img.shields.io/badge/Kernel-4.14.186-blue)]()
[![Android](https://img.shields.io/badge/Android-13-green)]()
[![SoC](https://img.shields.io/badge/SoC-MT6893-orange)]()
[![License](https://img.shields.io/badge/License-GPL--2.0-red)]()

> [!WARNING]
> This kernel is most likely only compatible with MIUI 14.0.4.0 (TKJCNXM).
> Other versions have not been tested. Use at your own risk.

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
- **SELinux stays Enforcing**, no dependency on permissive mode
- Rewritten `build.sh`, no hardcoded paths from the original author

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

- **Xiaomi `ares-r-oss`** — official Linux 4.14.186 kernel source
- **[Tkpointz/android_kernel_aresin](https://github.com/Tkpointz/android_kernel_aresin)** — community-maintained ares kernel baseline
- **[ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)** — root solution
- **[simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu)** — root hiding

---

## Known Issues

- SELinux must stay **Enforcing**, otherwise SUSFS hiding is weakened
- On permissive mode, KernelSU disables seccomp by design
- Some MTK drivers on 4.14 non-GKI emit clang-18 compatibility warnings; suppressed via `KCFLAGS="-Wno-error"`

---

## License

This project is based on the Linux kernel and is licensed under **GPL-2.0**. See [LICENSE](LICENSE).

---

## About

Stardust Kernel is maintained by an independent developer from Heilongjiang, China.
In Northeast China, the spark of free software and open hardware has always been there —
just not often seen.
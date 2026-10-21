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
- 修复 init 收不到 `KERNEL_SU_RC` 导致 `ksud` 从不启动、所有模块（Zygisk Next / LSPosed）失效的问题
- 加固 MTK GPU DVFS：`settle time` 归一化 + 自旋上限，修复偶发整机冻结
- 收窄 `misc_open()` 的全局锁范围，避免单个驱动 `open()` 卡死拖垮全系统
- 重写 `build.sh` 和 `build-inc.sh`，移除对原脚本作者硬编码路径的依赖

---

## 修复记录

| 问题 | 位置 | 根因与修复 |
|---|---|---|
| Zygisk Next / LSPosed 完全不生效 | `fs/read_write.c` | `SYSCALL_DEFINE3(read)` 里 `ksu_handle_sys_read()` 的调用被注释，init 读不到注入的 `KERNEL_SU_RC`，`ksud` 从未被执行 → 所有模块不加载。恢复该调用即可 |
| SELinux Enforcing 下卡 Logo 数十分钟 | 用户态（LSPosed 1.11） | `lspd` 的 `service package is not started` 自旋与 system_server 的 `ILSPApplicationService` 互等约 330 秒（`BpBinder transact 326780 ms`）。改用 LSPosed 1.9.x 后消失，与内核无关 |
| 偶发整机冻结、无 panic、无 AEE | `mtk_gpufreq_plat.c` | `__calculate_{vgpu,vsram}_settletime()` 的 `deltaV` 为负时，`deltaV/1250+9` 赋给 `unsigned` 回绕成 ~4.29e9，`udelay()` 忙等约 4295 秒，且全程持有 `misc_open` 的全局锁。现对负值返回 0，并夹到 2000us；两处 vgpu 自旋另加 64 次上限 |
| 单个 misc 驱动 `open()` 卡死拖垮全系统 | `drivers/char/misc.c` | `misc_open()` 原先在持有全局 `misc_mtx` 时调用驱动 `->open()`。现改为取到 `fops` 后释放锁再调用 |

### 运行时取证（可选）

`/data/adb/modules/ares_lastlog` 会用 `logcat -b all` 把日志持久化到 `/data/vendor/lastlog/`（8MB × 8 轮转）。
若再次出现冻结，强制重启后直接 `adb pull /data/vendor/lastlog` 即可拿到死前现场；
内核静默时用 `echo 1 > /proc/sys/kernel/sysrq` + `echo w`/`echo l` 抓 D 状态栈与 NMI 栈。

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

- SELinux **Enforcing** 现已可用（策略注入问题已修复）。早期“卡 Logo 数十分钟”已定位为 **LSPosed 1.11 的 `lspd` 启动自旋**，改用 LSPosed 1.9.x 后不再出现
- 若继续使用 LSPosed 1.11，仍可能出现 system_server 被 `ILSPApplicationService` 阻塞数十秒至数分钟的现象，与内核无关
- 内核未启用 `CONFIG_DETECT_HUNG_TASK` / `CONFIG_SOFTLOCKUP_DETECTOR`，内核侧卡死默认静默；排查时请用 `sysrq` 或 MTK `hang_detect`
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
- Fixed init never receiving `KERNEL_SU_RC`, which kept `ksud` from running and silently disabled every KernelSU module (Zygisk Next / LSPosed)
- Hardened MTK GPU DVFS: settle-time normalization + bounded spin loops, fixing an occasional whole-system freeze
- Narrowed the global lock in `misc_open()` so one blocking driver `open()` cannot freeze the entire system
- Rewritten `build.sh` and `build-inc.sh`, no hardcoded paths from the original author

---

## Fix Log

| Symptom | File | Root cause and fix |
|---|---|---|
| Zygisk Next / LSPosed completely inactive | `fs/read_write.c` | The `ksu_handle_sys_read()` call in `SYSCALL_DEFINE3(read)` was commented out, so init never saw the injected `KERNEL_SU_RC` and `ksud` was never executed, leaving every module unloaded. Restored the call |
| Boot stuck at logo for tens of minutes under SELinux Enforcing | userspace (LSPosed 1.11) | `lspd`'s `service package is not started` spin and system_server's `ILSPApplicationService` call waited on each other for ~330s (`BpBinder transact 326780 ms`). Switching to LSPosed 1.9.x removed it; unrelated to the kernel |
| Occasional hard freeze, no panic, no AEE dump | `mtk_gpufreq_plat.c` | In `__calculate_{vgpu,vsram}_settletime()`, a negative `deltaV` made `deltaV/1250+9` wrap into `unsigned` as ~4.29e9, turning `udelay()` into a ~4295s busy wait while holding the global lock from `misc_open`. Negative deltas now return 0 and are clamped to 2000us; both vgpu spin loops are bounded at 64 iterations |
| One blocking misc driver `open()` froze the system | `drivers/char/misc.c` | `misc_open()` used to call the driver's `->open()` while holding the global `misc_mtx`. It now drops the mutex before invoking it |

### Optional runtime forensics

The `/data/adb/modules/ares_lastlog` module persists `logcat -b all` into `/data/vendor/lastlog/` (8MB x 8 rotation).
If a freeze happens again, `adb pull /data/vendor/lastlog` right after a forced reboot.
For silent kernel hangs use `echo 1 > /proc/sys/kernel/sysrq` plus `echo w` / `echo l` to dump D-state stacks and NMI backtraces.

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

- SELinux **Enforcing** now works (the policy injection issue is fixed). The earlier "stuck at logo for tens of minutes" was traced to the **LSPosed 1.11 `lspd` bootstrap spin** and disappears with LSPosed 1.9.x
- With LSPosed 1.11 system_server may still be blocked inside `ILSPApplicationService` for tens of seconds to minutes; this is unrelated to the kernel
- The kernel does not enable `CONFIG_DETECT_HUNG_TASK` / `CONFIG_SOFTLOCKUP_DETECTOR`, so kernel-side hangs are silent by default; use `sysrq` or MTK `hang_detect` when investigating
- On permissive mode, KernelSU disables seccomp by design
- Some MTK drivers on 4.14 non-GKI emit clang-18 compatibility warnings; suppressed via `KCFLAGS="-Wno-error"`

---

## License

This project is based on the Linux kernel and is licensed under **GPL-2.0**. See [LICENSE](LICENSE).

---

## About

Stardust Kernel is maintained by an independent developer from Heilongjiang, China.
In Northeast China, the spark of free software and open hardware has always been there — just not often seen.
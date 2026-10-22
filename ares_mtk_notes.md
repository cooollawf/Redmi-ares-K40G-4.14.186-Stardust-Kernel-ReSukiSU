# 开发之外的往事

> **存档：2026-10-21，内核 #31（`Stardust-ares-schedutil-lock.zip`）**
>
> ares / MT6893 内核调试笔记 —— 记录 Redmi K40 Gaming（ares，MT6893 Dimensity 1200）在
> 4.14.186 + ReSukiSU + SUSFS 上的实测结论、踩坑记录和调试方法。**结论都带代码位置**，
> 避免以后重复踩。本文件是一个时间点上的存档，后续新的结论请另开文件。

- 设备：Redmi K40 Gaming（ares）/ POCO F3 GT（aresin）
- SoC：MT6893（4×A55 2.0G + 3×A78 2.6G + 1×A78 3.0G）
- 内核：4.14.186，non-GKI
- Root：ReSukiSU v4.1.0；隐藏：SUSFS v2.3.0
- Zygisk 宿主：NeoZygisk v2.4（zygisksu 模块）
- 系统：Android 13 / MIUI 14.0.4.0（TKJCNXM）

配置里两个容易找错路径的地方：

```
CONFIG_MTK_PLATFORM="mt6885"              # mt6893 家族共用这个字符串
CONFIG_MTK_GPU_VERSION="mali valhall r32p1"
# → Mali 真实路径是 gpu_mali/mali_valhall/mali-r32p1/...，不是 bifrost/r19p0
```

---

## 一、已定位并修复的问题

### 1. Zygisk Next / LSPosed 完全不生效（ksud 从未启动）

**根因**：`fs/read_write.c` 的 `SYSCALL_DEFINE3(read)` 里，`ksu_handle_sys_read()` 的调用被注释掉了，
只剩 extern 声明。init 因此收不到内核注入的 `KERNEL_SU_RC`（含 `exec /data/adb/ksud post-fs-data` 等），
ksud 从不执行 → 所有模块不加载 → `zygiskd` 不存在。

**判断依据**：`ps` 里没有 `ksud`、logcat 没有任何 ksud 日志、但管理器 App 正常（它走
`fs/exec.c` + `kernel/sys.c` 的 in-tree hook）。

**修复**（`fs/read_write.c`，约 :571-578）：

```c
#ifdef CONFIG_KSU
    extern int ksu_handle_sys_read(unsigned int fd, char __user **buf_ptr,
                                   size_t *count_ptr);
    ksu_handle_sys_read(fd, &buf, &count);
#endif
```

**验证**：`ps -A | grep -E 'zygisk|ksud'` 出现 `zygisk-ptrace64` / `zygiskd64`；logcat 出现
`read init.rc, comm: init, rc_count: ...`（`ksud_integration.c:736`）。

> 注：SUSFS 的三条 init.rc 注入路径在这里只有 read hook 可用（LSM `file_permission` 需要
> `CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK`，而本配置 manual/tracepoint 都没开）。

### 2. SELinux Enforcing 下卡 Logo 数十分钟

**不是内核问题**。实测证据：

```
BpBinder: Slow Binder: transact took 326780 ms,
  interface=org.lsposed.lspd.service.ILSPApplicationService
LSPosedService: service package is not started, wait 1s.   ← 循环 330 秒
boot_progress_preload_end → boot_progress_system_run      ← 空白 327 秒
```

即：`lspd`（LSPosed 1.11）启动时等管理器/系统服务，同时 system_server 的第一笔 LSPosed binder 调用在等
lspd，互相死等到超时。**换 LSPosed 1.9.x 后消失**，与内核、SELinux、SUSFS 无关。

附带发现：SF 在这段时间 `RT throttling activated` 每秒刷一条，是在陪等，不是它自己坏。

### 3. 偶发整机冻结（无 panic、无 AEE）

**根因**：MTK GPU DVFS 的 settle time 无符号回绕。

`drivers/misc/mediatek/base/power/gpufreq_v1/mt6893/mtk_gpufreq_plat.c`：

```c
/* __mt_gpufreq_volt_switch() :2756 */
final_settle_time = max(vgpu_settle_time, vsram_settle_time);
udelay(final_settle_time);          // ← 变成 udelay(4.29e9) ≈ 忙等 4295 秒
```

`__calculate_{vgpu,vsram}_settletime(bool mode, int deltaV)` 里 `settleTime = deltaV / 1250 + 9;`，
`deltaV` 为负时结果赋给 `unsigned int` → 回绕。而这条链路是在 `misc_open()` 的**全局 misc_mtx** 里跑的，
所以一次调频异常 = 全系统 misc 设备（audio/camera/allocator/update_engine/mfp…）全部卡死，adb 却还活着
（adbd 不碰 misc 设备）。

**NMI 栈（sysrq l）**：

```
__delay → __udelay → __mt_gpufreq_volt_switch+0x100
__mt_gpufreq_set+0x100 → mt_gpufreq_target → mtk_common_gpufreq_commit
pm_callback_power_on → kbase_pm_clock_on → kbase_pm_do_poweron
kbase_pm_update_active → kbase_open → misc_open → SyS_openat
```

**修复三处**：

1. `__mt_gpufreq_volt_switch()`：`final_settle_time > 2000` 时打日志并夹到 2000us；
2. `__calculate_{vgpu,vsram}_settletime()`：`deltaV <= 0` 直接返回 0，正常值再夹 2000us；
3. `__mt_gpufreq_set()`：两处 `while (g_cur_opp_vgpu != vgpu_new)` 加 64 次 `spin_guard`。

**验证**：`dmesg | grep 'bogus settle'` / `grep 'spin guard'`；不再冻结则说明没再走到异常路径。

### 4. 单个 misc 驱动 open 卡死拖垮全系统

**根因**：`drivers/char/misc.c` 的 `misc_open()` 在持有全局 `misc_mtx` 时调用驱动自己的 `->open()`。

**修复**：取到 `fops` 后先 `mutex_unlock(&misc_mtx)`，再调 `file->f_op->open()`（:144-168）。

**验证**：卡死时 `ps -A | grep misc_open` 不再出现一排等待者。

> 副作用说明：`struct miscdevice *c` 在解锁后理论上可能被 deregister，本机 misc 设备均为内建、
> 不会运行时注销，可接受；若将来引入可卸载 misc 驱动需重新评估。

### 5. 温控过保守（57°C 就一刀切降频）

**原状**：`drivers/misc/mediatek/thermal/mt6893/inc/tzcpu_initcfg.h`

```c
#define TZCPU_INITCFG_NUM_TRIPS (2)
#define TZCPU_INITCFG_TRIP_0_TEMP (117000)   // mtktscpu-sysrst
#define TZCPU_INITCFG_TRIP_1_TEMP (57000)    // cpu_adaptive_0（ATM）
// TRIP_2..9 的 COOLER 全是空串 —— NUM_TRIPS=2 时这些定义是死代码
```

57°C 绑定的是 **ATM**（`thermal/common/coolers/mtk_cooler_atm.c:3979` 注册 `cpu_adaptive_0/1/2`，
按 cluster 各一个），一旦越过就立刻压频，体感“用一会就卡手”。

**现配置（三级）**：

```c
#define TZCPU_INITCFG_NUM_TRIPS (3)
#define TZCPU_INITCFG_TRIP_0_TEMP (110000)  "mtktscpu-sysrst"   // 110°C 重启
#define TZCPU_INITCFG_TRIP_1_TEMP (80000)   "cpu_adaptive_0"    // 80°C ATM 小幅介入
#define TZCPU_INITCFG_TRIP_2_TEMP (95000)   "ares_cpu_cap"      // 95°C 锁频
```

配套新增 cooler：`drivers/misc/mediatek/thermal/ares_cooler_cpucap.c`
（注册名 `ares_cpu_cap`，走 PPM `mt_ppm_hard_userlimit_cpu_freq()`，三簇统一锁 `ARES_CAP_FREQ_KHZ`，
默认 1.2GHz；`state=0` 时用 `-1` 解除限制）。`thermal/Makefile` 加 `obj-y += ares_cooler_cpucap.o`。

**注意**：`trip_temp[0]` 按 MTK 注释必须是“硬件保护点”，所以 sysrst 保留在 index 0，只是温度从 117 改 110。

### 6. BCCT 充电限流（分析结论，未改代码）

真正编译进内核的是 `mtk_cooler_bcct_v1.c`（**不是** `mtk_cooler_bcct.c`；`out/.../coolers/` 只有 v1 的 .o）。

```c
/* mtk_cooler_bcct_v1.c:571 */
MTK_CL_BCCT_SET_LIMIT(1000, cl_bcct_state[0]);   // 1A
MTK_CL_BCCT_SET_LIMIT(500,  cl_bcct_state[1]);   // 0.5A
MTK_CL_BCCT_SET_LIMIT(0,    cl_bcct_state[2]);   // 0A ← 一旦拉起 = 停充
```

- `mtk_cl_bcct_set_bcct_limit()` 取所有活跃实例的 **min**，三个都拉起 → 0A；
- 限的是**电池侧**充电电流：`chrlmt_set_limit(handle, input_curr, bat_curr)` → `set_bat_charging_current_limit()`；
- `if (chrlmt_is_lcmoff) state = 0;`（息屏自动取消限制）；
- **MT6893 的 `tzbatt_initcfg.h` 里没有任何 trip 绑 bcct**（只有 60°C → `mtktsbattery-sysrst`），
  所以它只可能被用户态（`mi_thermald` / thermal HAL）拉起。

**运行时调参（无需编译，重启失效）**：

```
写：/proc/driver/thermal/clbcct     格式 "<klog_on> <limit0> <limit1> <limit2>"，单位 mA，-1=不限
读：/proc/bcctlmt                   显示 chrlmt_*_curr_limit 与各实例 preset
```

实测现场（未拉起时）：`cl_bcct_cur_limit 65535`、`chrlmt_bat_chr_curr_limit -1`、
`mtk-cl-bcct0X ... state 0` —— 说明 bcct 空闲，充电慢不是它干的。

电池信息（`ares-mt6893.dtsi:276`）：**单电芯 1S**，`battery_cv=4460000`(4.46V)，
`current_max=12.4A`，CV 阶梯 `8.94/7.45/5.96A`。所以 W→mA 换算必须以 1S 近似
（45W≈10.7A、35W≈8.3A、30W≈7.1A @4.2V，需实测标定）。

---

## 二、MTK 调度/温控/GPU 文件地图

### 温控

| 内容 | 路径 |
|---|---|
| 编译入口 | `drivers/misc/mediatek/thermal/Makefile`（PDIR=mt6893，几乎全 obj-y） |
| CPU 温区 trip | `thermal/mt6893/inc/tzcpu_initcfg.h` |
| 电池温区 trip | `thermal/mt6893/inc/tzbatt_initcfg.h` |
| 温区实现 | `thermal/common/thermal_zones/mtk_ts_cpu.c`（trip/bind 数组） |
| 平台采样 | `thermal/mt6893/src/`（mtk_tc.c、mtk_ts_6359*.c、mtk_ti_6315.c） |
| ATM cooler | `thermal/common/coolers/mtk_cooler_atm.c`（`cpu_adaptive_0/1/2`） |
| BCCT cooler | `thermal/common/coolers/mtk_cooler_bcct_v1.c` |
| 温控→压频桥 | `base/power/ppm_v3/src/mtk_ppm_policy_thermal.c` |

**DTS 里没有 `thermal-zones` 节点**（全树只有 mt8173 有），zone 是驱动里动态注册的，别去 dts 找温控表。

### CPU 调度

| 内容 | 路径 |
|---|---|
| schedutil（MTK 改） | `kernel/sched/cpufreq_schedutil.c` |
| 非线性频率映射 | `kernel/sched/cpufreq_schedutil_plus.c`（被 `#include`，`CONFIG_NONLINEAR_FREQ_CTL=y`） |
| EAS | `kernel/sched/eas_plus.c`、`energy_plus.c` |
| `capacity_margin` | `kernel/sched/fair.c:159 = 1280`，运行时被 `performance/fpsgo_v3/fbt/fbt_cpu.c:691` 改 |
| cpufreq 驱动 | `base/power/cpufreq_v1/src/`（mtk_cpufreq_main/hybrid/interface） |
| PPM | `base/power/ppm_v3/src/`（main + 各 policy） |
| perfmgr/fpsgo | `drivers/misc/mediatek/performance/` |
| 调压 | `base/power/eem_v2/mt6893/`、`eemgpu_v2/mt6893/` |

### GPU

| 内容 | 路径 |
|---|---|
| Mali 源码 | `gpu/gpu_mali/mali_valhall/mali-r32p1/drivers/gpu/arm/midgard/` |
| 平台配置 | `.../platform/mt6893/` |
| DVFS 门限 | `.../backend/gpu/mali_kbase_pm_metrics.c`（`KBASE_PM_VSYNC_MIN/MAX_UTILISATION`=70/90、`NO_VSYNC`=10/40、`TIME_SHIFT`=8） |
| GED（MIUI 调参） | `gpu/ged/src/ged_dvfs.c`、`ged_monitor_3D_fence.c`、`ged_gpu_tuner.c` |
| 调频驱动 | `base/power/gpufreq_v1/mt6893/mtk_gpufreq_plat.c` |

---

## 三、运行时调试接口

```sh
# 温度 / trip
cat /sys/class/thermal/thermal_zone*/type
cat /sys/class/thermal/thermal_zone*/temp
cat /sys/class/thermal/thermal_zone*/trip_point_*_temp
cat /proc/driver/thermal/tzcpu
cat /proc/driver/thermal/clatm_setting          # ATM 设定/状态

# 充电 / BCCT
cat /proc/bcctlmt                               # chrlmt 生效值（input/battery）
cat /proc/driver/thermal/clbcct                 # 各实例 preset + state（可写）
cat /sys/class/power_supply/battery/{voltage_now,current_now,constant_charge_current_max}

# CPU 频率 / 调度
cat /sys/devices/system/cpu/cpufreq/policy*/affected_cpus
cat /sys/devices/system/cpu/cpufreq/policy*/scaling_{min,max}_freq
cat /sys/devices/system/cpu/cpufreq/policy*/cpuinfo_{min,max}_freq
cat /sys/devices/system/cpu/cpufreq/policy*/schedutil/{up,down}_rate_limit_us    # RW
cat /proc/ppm/policy/hard_userlimit_{max,min}_cpu_freq                            # PPM 硬限

# GPU
cat /proc/gpufreq/gpufreq_opp_dump
cat /proc/gpufreq/gpufreq_limit_table
cat /sys/kernel/ged/hal/*
```

本机三簇（实测）：

| policy | 核 | 硬件 max | 档位 | min |
|---|---|---|---|---|
| policy0 | 0-3（A55） | 2.0 GHz | 16 | 500 MHz |
| policy4 | 4-6（A78） | 2.6 GHz | 16 | 437 MHz |
| policy7 | 7（A78） | 3.0 GHz | 16 | 659 MHz |

schedutil `up/down_rate_limit_us` 的**真实**默认值是 1000/1000（1 ms/1 ms），但这个是
**fpsgo 推上去的**，不是 governor 自己的选择：`sugov_init()` 里写的是
`cpufreq_policy_transition_delay_us()`（本机实测被 fpsgo 的 push 覆盖，见第八节）。
`min_rate_limit_ns = min(up, down)`。

`struct sugov_tunables` 是 **per-policy** 的（实测：写 `policy4/schedutil/up_rate_limit_us`
不会影响 `policy0`），所以调 schedutil 必须三簇分别写。

---

## 四、卡死/冻结的取证方法（按有效性排序）

| 手段 | 结论 |
|---|---|
| `sysrq w`（D 状态栈） | **有效**。先 `echo 1 > /proc/sys/kernel/sysrq`（默认 0） |
| `sysrq l`（各 CPU NMI 栈） | **有效**，抓 R 状态自旋最有用 |
| `/proc/<pid>/stack` | 有效，但只看内核态且需 root |
| 持久化 logcat | 有效：`logcat -b all -f /data/vendor/lastlog/logcat -r 8192 -n 8`，已做成模块 `ares_lastlog` |
| `pstore` | **无效**：ares.dtb 里没有 ramoops 节点，`/sys/fs/pstore` 永远空 |
| `/proc/last_kmsg` | **基本无效**：MTK ram_console 只输出 header（`ram console header, hw_status: 0`） |
| AEE 转储 | 位置 `/data/vendor/aee_exp/`。KE（kernel exception）才有栈；纯 hang 不会产生 |
| `debuggerd -b <pid>` | **慎用**：失败会把目标留在 ptrace_stop，需 `kill -CONT` 救活 |

内核未启用 `CONFIG_DETECT_HUNG_TASK` / `CONFIG_SOFTLOCKUP_DETECTOR`，所以内核侧卡死默认**完全静默**。

---

## 五、不要动的东西

1. **`eem_v2/` / `eemgpu_v2/` 的电压表** —— 改错直接死机或伤硬件；要动只动 settle/上限逻辑。
2. **uPower 表的 capacity 值** —— schedutil 非线性映射依赖它，改了会连带影响 EAS 任务放置。
3. **`trip_temp[0]` 的 sysrst 语义** —— 必须留在 index 0 作为硬件保护点。
4. **`__mt_gpufreq_set` 的 64 次护栏** —— 去掉会把冻结放回来。
5. **`misc_open` 放锁那处** —— 回退会恢复“一个驱动卡死、全系统 misc 陪葬”。

---

## 六、待办 / 未决

- [ ] 偶发冻结：`ares_lastlog` 已就位，等复现后 `adb pull /data/vendor/lastlog`。
- [ ] LSPosed 1.11 → 1.9 的切换效果（开机时间应恢复几十秒）。
- [ ] Momo 检出项：`hidden_api_policy=0`（`settings delete global hidden_api_policy` 可回默认）；
      `bl 未锁定`（来自 init 读 cmdline 导入的 `ro.boot.flash.locked` / `verifiedbootstate`，
      内核侧要改 `saved_command_line`，有 verity/vold/OTA 风险，暂缓）。
- [ ] BCCT 默认值是否固化为 8000/6000/4000 mA（需先确认 67W 充电器下的实际功率）。
- [ ] `ares_cpu_cap` 95°C 锁频是否改成按簇分级（如 1.5/1.2/1.0 GHz）。
- [x] schedutil `up=0 / down=10000`：已定位为 fpsgo→eas_ctrl 覆盖，已在内核侧锁死（见第八节）。

---

## 七、构建与刷机

```bash
./build.sh        # 全量（改头文件/defconfig/Kconfig 后必须用这个）
./build-inc.sh    # 增量
# 产物：out/arch/arm64/boot/Image.gz-dtb
```

打包（AnyKernel3）：

```bash
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3/Image.gz-dtb
cd AnyKernel3 && zip -r9 ../Stardust-ares-<tag>.zip * -x "*.bak*" -x "README.md"
```

> 注意：`AnyKernel3/Image.gz-dtb` 会在打包时被覆盖，回退用的旧镜像单独备份为
> `Image.gz-dtb.bak-<date>`（当前有 `bak-20260916`）。

刷机后确认版本（**别用 `uname`**，ReSuSFS 会 spoof 它，见第八节）：

```sh
adb shell cat /proc/version
# Linux version 4.14.186-Stardust-Kernel-ReSukiSU-g... #31 SMP PREEMPT ... CST 2026
adb shell cat /sys/class/thermal/thermal_zone4/trip_point_*_temp   # 110000 80000 95000
```

---

## 八、schedutil 被谁覆盖 / 为什么 `uname` 不可信（2026-10-21 晚实测）

### 8.1 `uname -a` 是假的：ReSuSFS 的 uname spoof

```
# dmesg（启动早期）
susfs:[0][1018][susfs_set_uname] set spoofed release: '4.14.186-gb6ff9ed3',
        version: '#1 SMP PREEMPT Mon Jul 10 03:58:28 UTC 2023'
```

- `/proc/version` → 真实构建（`...-Stardust-Kernel-ReSukiSU-g5a6353b1b-dirty #31 ... CST 2026`）
- `uname -a` / `uname(2)` → 被 `CONFIG_KSU_SUSFS_SPOOF_UNAME` 换成上面那串库存版本

所以以后**验版本一律用 `/proc/version`**，`uname` 只用来确认 spoof 生效。

### 8.2 schedutil rate limit 的真实覆盖链

```
sugov_init()                      up=0 / down=10000        （我们打的补丁）
fpsgo  fbt_cpu.c: fbt_set_down_throttle_locked()
   ├─ 有帧流在跑        → update_schedplus_*_throttle_ns(FPSGO, 0)      → 三簇 0/0
   └─ reset/退出（-1）  → eas_ctrl 用 default_*_ns = 1000000 ns = 1000us → 三簇 1000/1000
eas_ctrl  update_schedplus_*_throttle_ns()
   └─ schedutil_set_up/down_rate_limit_us(cpu_id[i], ns/1000)   （per-policy 循环）
```

结论：schedutil 的 rate limit 实测由 fpsgo 的状态决定（渲染中 0/0、空闲 1000/1000），
`play` 与否会导致 governor 行为不同，我们能观测到的 `0/10000` 只是“恰好在两次 push 之间”。

**内核侧修复（已做）**：

| 文件 | 改动 |
|---|---|
| `fpsgo_v3/fbt/src/fbt_cpu.c` | `fbt_set_down_throttle_locked()` 不再调 `update_schedplus_*_throttle_ns()`，只保留 `down_throttle_ns` 记账（sysfs 节点语义不变） |
| `boost_ctrl/eas_ctrl/eas_ctrl.c` | `default_schedplus_down_throttle_ns=10000000`、`default_schedplus_up_throttle_ns=0`（跟 `sugov_init()` 对齐，防止别的 kicker 再推回 1 ms） |

效果：schedutil 永久保持 **up=0 / down=10000**（= AOSP/GKI 默认），与是否在渲染无关。

**运行时验证/应急开关**（不起作用在内核，重启即失效）：

```sh
# 1) 锁住 eas_ctrl（debug != -1 时不再 push，但只写 cpu0 那一个 policy）
echo 0        > /proc/perfmgr/boost_ctrl/eas_ctrl/debug_schedplus_up_throttle     # 单位 ns
echo 10000000 > /proc/perfmgr/boost_ctrl/eas_ctrl/debug_schedplus_down_throttle  # 单位 ns
# 2) 三簇分别写真正生效的值
for p in 0 4 7; do
  echo 0     > /sys/devices/system/cpu/cpufreq/policy$p/schedutil/up_rate_limit_us
  echo 10000 > /sys/devices/system/cpu/cpufreq/policy$p/schedutil/down_rate_limit_us
done
```

> 坑：往 debug 节点写 `-1` 会走 `schedutil_set_*_rate_limit_us(0, cur_xxx_ns)`——
> 把 **ns 当 us** 用，`cur=-1` 时等于 `4294967295 us`，等于永久禁止降频。别写 `-1`。

### 8.3 三级温控实测绑定（`thermal_zone4` = `mtktscpu`）

| trip | 温度 | cooling device | 实测 |
|---|---|---|---|
| 0 | 110000 | `mtktscpu-sysrst` | 硬件保护重启 |
| 1 | 80000 | `cpu_adaptive_0` | ATM 自适应降频 |
| 2 | 95000 | `ares_cpu_cap` | 写 `cur_state=1` 后 `scaling_max_freq`：cluster0 1075000、cluster1 1162000（PPM 取 ≤1.2 GHz 的最近档）；写回 0 立刻恢复 |

- `mt_ppm_hard_userlimit_cpu_freq()` 的结果**会**反映到 `scaling_max_freq`，说明 PPM 硬限是真生效的。
- `ares_cpu_cap` 原来每 200 ms 被 thermal core 调一次 `set_cur_state()`，dmesg 里 2 分钟刷
  ~900 行 `cpu cap OFF`；已加“状态不变直接返回”，同时省掉重复的 PPM 调用。

### 8.4 屏幕熄灭时 cpu7 被压到 659 MHz 是正常的

`mWakefulness=Dozing` 时 perfmgr 的 CFP（`/proc/perfmgr/boost_ctrl/cpu_ctrl/`，
`cfp_enable=1`、`cfp_down_opp=cfp_up_opp=15`）把 prime core 钉在最低档（659 MHz），
`/proc/ppm/policy/userlimit_min/max_cpu_freq` 里 cluster2 是 `15/15`。
点亮屏幕/有帧流后会自动放开，不要当成 bug。

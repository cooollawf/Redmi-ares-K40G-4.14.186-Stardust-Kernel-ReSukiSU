#!/bin/bash
set -e

# === 配置 ===
DEFCONFIG="ares_user_defconfig"
KERNEL_TARGET="Image.gz-dtb"
JOBS=$(nproc --all)

# === 工具链路径（可通过环境变量覆盖）===
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$(pwd)/../clang-18_neutron}"
if [ ! -d "$TOOLCHAIN_DIR" ]; then
    echo "错误：找不到工具链目录 $TOOLCHAIN_DIR"
    echo "请设置 TOOLCHAIN_DIR 环境变量，或下载 clang-18 到该目录"
    exit 1
fi
export PATH="$TOOLCHAIN_DIR/bin:$PATH"

# === 工具链检测 ===
for cmd in clang aarch64-linux-gnu-gcc arm-linux-gnueabi-gcc; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "错误：找不到 $cmd"
        echo "请安装：sudo apt install gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi"
        exit 1
    fi
done

# === ccache（可选）===
if command -v ccache &>/dev/null; then
    export USE_CCACHE=1
    ccache -M 32G >/dev/null 2>&1 || true
    echo "==> 使用 ccache 加速编译"
fi

# === 构建信息 ===
export ARCH=arm64
export LC_ALL=C
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-stardust}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-localhost}"

# === 全量清理（改了源码必须做）===
echo "==> 清理 out/"
rm -rf out/

# === 配置 ===
echo "==> 生成 defconfig..."
make O=out ARCH=arm64 "$DEFCONFIG"

# === 编译 ===
echo "==> 开始编译（$JOBS 并发）..."
make -j"$JOBS" O=out \
    ARCH=arm64 \
    CC="clang" \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
    STRIP=llvm-strip \
    AS=llvm-as \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=aarch64-linux-gnu-objcopy \
    OBJDUMP=llvm-objdump \
    CONFIG_NO_ERROR_ON_MISMATCH=y \
    KCFLAGS="-Wno-error" \
    "$KERNEL_TARGET" 2>&1 | tee image-build.log

echo "==> 编译完成"
echo "    产物：out/arch/arm64/boot/$KERNEL_TARGET"
ls -lh "out/arch/arm64/boot/$KERNEL_TARGET" 2>/dev/null || echo "警告：未找到产物"
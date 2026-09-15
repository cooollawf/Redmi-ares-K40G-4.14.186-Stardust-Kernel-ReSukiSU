#!/bin/bash
set -e

# === 配置 ===
DEFCONFIG="ares_user_defconfig"
KERNEL_TARGET="Image.gz-dtb"
JOBS=$(nproc --all)

# === 工具链路径 ===
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$(pwd)/../clang-18_neutron}"
if [ ! -d "$TOOLCHAIN_DIR" ]; then
    echo "错误：找不到工具链目录 $TOOLCHAIN_DIR"
    exit 1
fi
export PATH="$TOOLCHAIN_DIR/bin:$PATH"

# === 工具链检测 ===
for cmd in clang aarch64-linux-gnu-gcc arm-linux-gnueabi-gcc; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "错误：找不到 $cmd"
        exit 1
    fi
done

# === ccache（保留缓存）===
if command -v ccache &>/dev/null; then
    export USE_CCACHE=1
    ccache -M 32G >/dev/null 2>&1 || true
    echo "==> 使用 ccache"
fi

# === 构建信息 ===
export ARCH=arm64
export LC_ALL=C
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-stardust}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-localhost}"

# === 增量编译：不删 out/，不清 ccache ===
# 只重新生成配置（防止有人改了 defconfig 后忘了同步）
echo "==> 更新 defconfig..."
make O=out ARCH=arm64 "$DEFCONFIG"

echo "==> 增量编译（$JOBS 并发）..."
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
ls -lh "out/arch/arm64/boot/$KERNEL_TARGET" 2>/dev/null || echo "警告：未找到产物"
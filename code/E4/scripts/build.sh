#!/usr/bin/env bash
# build.sh — C8051F310 多文件汇编构建脚本
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDCC_BIN="/home/yzy/.eide/tools/sdcc_mcs51/sdcc-4.5.0-with-binutils/bin"
SDCC="${SDCC_BIN}/sdcc"
AS="sdas8051"
LD="sdld"

cd "$ROOT"

# 源文件列表（vectors 必须放在最前）
ASM_SRCS="src/vectors.asm src/init.asm src/isr.asm src/display.asm src/keypad.asm src/led_bar.asm src/tables.asm src/main.asm src/calculator.asm"
INC_DIRS="inc"
OUT_BASE="c8051f310"
IRAM_SIZE="256"
XRAM_SIZE="0"
CODE_SIZE="8192"
CODE_LOC="0x0000"

OUT_DIR="build/Debug"
mkdir -p "$OUT_DIR"

# 生成汇编器 -I 头文件路径参数
AS_FLAGS=""
for d in $INC_DIRS; do
    AS_FLAGS="$AS_FLAGS -I${ROOT}/${d}"
done

# 逐个汇编源文件，生成 .rel
REL_FILES=""
for src in $ASM_SRCS; do
    base="$(basename "${src%.asm}")"
    rel="${OUT_DIR}/${base}.rel"
    echo "[AS] $src"
    "$AS" -plosgff $AS_FLAGS -o "$rel" "${ROOT}/${src}"
    REL_FILES="$REL_FILES $rel"
done

# 使用 sdld 将所有 .rel 链接为 .ihx
# -i = Intel Hex 输出，-m = 生成 map 文件，-x = 地址用十六进制显示
# 段地址布局：VECTOR 固定在 0x0000，其他 CODE 段从 0x0100 起
echo "[LD] ${OUT_DIR}/${OUT_BASE}.ihx"
"$LD" -nimx \
    -b VECTOR=0x0000 \
    -b INIT_CODE=0x0100 \
    -b ISR_CODE=0x0200 \
    -b DISP_CODE=0x0300 \
    -b KEY_CODE=0x0400 \
    -b LED_CODE=0x0500 \
    -b TABLES=0x0600 \
    -b MAIN_CODE=0x0700 \
    -b CALC_CODE=0x0900 \
    "${OUT_DIR}/${OUT_BASE}" \
    $REL_FILES

# 复制一份 .hex 供烧录脚本使用
cp "${OUT_DIR}/${OUT_BASE}.ihx" "${OUT_DIR}/${OUT_BASE}.hex"

echo "Build OK -> ${OUT_DIR}/${OUT_BASE}.hex"

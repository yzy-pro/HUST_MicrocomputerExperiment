#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/build/Debug"
OBJ_DIR="$OUT_DIR/.obj/src"

PROJECT_NAME="89c52_sdcc_demo"
SRC_FILE="$ROOT_DIR/src/main.c"

TOOL_BIN_DEFAULT="$HOME/.eide/tools/sdcc_mcs51/sdcc-4.5.0-with-binutils/bin"
TOOL_BIN="${SDCC_BIN_DIR:-$TOOL_BIN_DEFAULT}"
SDCC="$TOOL_BIN/sdcc"
OBJCOPY="$TOOL_BIN/i51-elf-objcopy"
OBJDUMP="$TOOL_BIN/i51-elf-objdump"

CFLAGS=(
  -c
  --std-c99
  -I"$ROOT_DIR/inc"
  -I"$ROOT_DIR/src"
  -mmcs51
  --opt-code-speed
  --iram-size 256
  --xram-size 0
  --code-size 8192
  --stack-auto
  --nooverlay
  -MMD
)

LDFLAGS=(
  -mmcs51
  --iram-size 256
  --xram-size 0
  --code-size 8192
  --stack-auto
  --nooverlay
)

clean() {
  rm -f "$OUT_DIR/$PROJECT_NAME.elf" \
        "$OUT_DIR/$PROJECT_NAME.hex" \
        "$OUT_DIR/$PROJECT_NAME.map" \
        "$OUT_DIR/$PROJECT_NAME.elf.asm" \
        "$OBJ_DIR/main.o" \
        "$OBJ_DIR/main.d" \
        "$OBJ_DIR/main.asm"
}

require_tools() {
  [[ -x "$SDCC" ]] || { echo "[ERR] sdcc not found: $SDCC"; exit 1; }
  [[ -x "$OBJCOPY" ]] || { echo "[ERR] i51-elf-objcopy not found: $OBJCOPY"; exit 1; }
  [[ -x "$OBJDUMP" ]] || { echo "[ERR] i51-elf-objdump not found: $OBJDUMP"; exit 1; }
}

build() {
  mkdir -p "$OBJ_DIR"

  echo "[1/3] Compiling: src/main.c"
  "$SDCC" "${CFLAGS[@]}" -o "$OBJ_DIR/main.o" "$SRC_FILE"

  echo "[2/3] Linking: $PROJECT_NAME.elf"
  "$SDCC" "${LDFLAGS[@]}" "$OBJ_DIR/main.o" -o "$OUT_DIR/$PROJECT_NAME.elf"

  echo "[3/3] Generating HEX"
  "$OBJCOPY" -O ihex "$OUT_DIR/$PROJECT_NAME.elf" "$OUT_DIR/$PROJECT_NAME.hex"
  "$OBJDUMP" -D "$OUT_DIR/$PROJECT_NAME.elf" > "$OUT_DIR/$PROJECT_NAME.elf.asm"

  echo "[OK] Build finished"
  echo "     ELF: $OUT_DIR/$PROJECT_NAME.elf"
  echo "     HEX: $OUT_DIR/$PROJECT_NAME.hex"
}

case "${1:-build}" in
  build)
    require_tools
    build
    ;;
  clean)
    clean
    echo "[OK] Clean finished"
    ;;
  rebuild)
    require_tools
    clean
    build
    ;;
  *)
    echo "Usage: $0 [build|clean|rebuild]"
    exit 1
    ;;
esac

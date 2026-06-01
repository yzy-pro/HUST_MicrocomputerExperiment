#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDCC="/home/yzy/.eide/tools/sdcc_mcs51/sdcc-4.5.0-with-binutils/bin/sdcc"
OUT_DIR="$ROOT/build/Debug"
OUT_BASE="c8051f310"
cd "$ROOT"
mkdir -p "$OUT_DIR"
"$SDCC" --std-c99 -Iinc -Isrc -mmcs51 --opt-code-speed --nooverlay --stack-auto --iram-size 256 --xram-size 0 --code-size 8192 --out-fmt-ihx -o "${OUT_DIR}/${OUT_BASE}.ihx" ./src/main.c

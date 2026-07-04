# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Embedded firmware for a C8051F310 MCU (MCS-51 architecture) implementing a smart waste-classification bin system. Four bins (plastic/paper, glass/metal, food waste, hazardous) with 7-segment capacity displays, LED bar countdown, 4×4 keypad, and buzzer. Written in **pure MCS-51 assembly** using `sdas8051` assembler and `sdld` linker.

## Build & Flash

**Build** (outputs `build/Debug/c8051f310.ihx` and `.hex`):
```bash
bash ./scripts/build.sh
```

All source files and memory map are configured inside `scripts/build.sh`. The assembler is the system `sdas8051` (from `apt install sdcc`); the SDCC compiler at `/home/yzy/.eide/tools/sdcc_mcs51/sdcc-4.5.0-with-binutils/bin/sdcc` is **not** used for assembly — only `sdas8051` + `sdld` are needed.

**Flash** via Silicon Labs C2 debug adapter:
```bash
bash ./scripts/flash.sh                        # default serial EC320126621
bash ./scripts/flash.sh -f build/Debug/c8051f310.hex -s <serial> -t c2
bash ./scripts/flash.sh -l                     # list connected devices
```
Flash tools live at `/home/yzy/code/MicrocomputerExperiment/tools/siliconlabs-c8051-efm8-utils/`.

## Module Structure

Each hardware concern is a separate `.asm` file. The linker map assigns each module its own fixed code area:

| File | Area | Address | Responsibility |
|------|------|---------|----------------|
| `src/vectors.asm` | VECTOR | 0x0000 | Reset + INT0 + Timer0 vectors |
| `src/init.asm` | INIT_CODE | 0x0100 | MCU init, oscillator, ports, Timer0, random seed, entry point `START` |
| `src/isr.asm` | ISR_CODE | 0x0200 | `EXT0_ISR` (Kint early-close), `TIMER0_ISR` (1ms tick) |
| `src/display.asm` | DISP_CODE | 0x0300 | `REFRESH_ALL`, `DELAY_DIG`, `GET_SEG` (blink/full overlay) |
| `src/keypad.asm` | KEY_CODE | 0x0400 | `SCAN_KEY`, `READ_COL`, `DEBOUNCE_DELAY` |
| `src/led_bar.asm` | LED_CODE | 0x0500 | `UPDATE_LED_BAR`, `SHIFT_LED_BAR` (74HCT164 driver) |
| `src/tables.asm` | TABLES | 0x0600 | `SEG_TAB`, `LED_BAR_TAB`, `KEY_REMAP_TAB` |
| `src/main.asm` | MAIN_CODE | 0x0700 | `MAIN_LOOP`, bin state machine, `GET_CAP`, `DEC_CAP`, `FULL_ALERT`, `PROP_CLEAR` |
| `src/calculator.asm` | CALC_CODE | 0x0900 | Calculator mode entry, key state machine, arithmetic/display formatting |

## Shared Headers

- `inc/sfr.inc` — all C8051F310 SFR addresses and bit addresses (include in every module)
- `inc/iram.inc` — IRAM symbol definitions (0x30–0x4F), shared state across all modules

Include with: `.include "sfr.inc"` (assembler is invoked with `-I inc/`).

## IRAM Layout

| Address | Symbol | Purpose |
|---------|--------|---------|
| 0x30–0x33 | CAP0–CAP3 | Bin capacities (0–9) |
| 0x34–0x35 | KEYNOW, KEYLAST | Current/previous key scan code |
| 0x36–0x39, 0x3B | ROWIDX, TMP, CNT, LEDREG, LASTBAR | Scratch/display state |
| 0x42–0x43 | LIDLO/LIDHI | 16-bit lid-open countdown (ms ticks, decremented by Timer0 ISR) |
| 0x44–0x45 | BLKDIV/BLKFLG | 5 Hz blink divider/flag |
| 0x46–0x47 | HINTLO/HINTHI | Full-alert buzzer countdown (1000ms) |
| 0x4D–0x4F | LIDOPEN, SELBIN, FULLBIN | Lid state, selected bin (0-3/0xFF), full-alert bin (0-3/0xFF) |

## Key Hardware Constraints

- Code size limit: 8 KB. Current build is ~2.5 KB — well under limit.
- IRAM: 256 bytes only, no XRAM. All variables must fit in 0x30–0x7F.
- Timer0 reload: `TH0=0xF8, TL0=0x06` for 1ms at 24.5 MHz / 12 (SYSCLK/12 mode).
- `SHIFT_LED_BAR` disables global interrupts (`clr EA`) during the 74HCT164 shift sequence.
- Long forward jumps in `led_bar.asm` use `ljmp` not `sjmp` (>127 byte range).
- Key codes K10–K13 are bin category keys (KF1–KF4); K14 enters calculator mode; K15 = F6 (property clear).

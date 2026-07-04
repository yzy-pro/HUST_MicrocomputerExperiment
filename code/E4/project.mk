# project.mk — 源文件清单
# 构建脚本读取这些变量。

OUT_BASE   = c8051f310
IRAM_SIZE  = 256
XRAM_SIZE  = 0
CODE_SIZE  = 8192
CODE_LOC   = 0x0000

# ASM 源文件列表，使用空格分隔（vectors 必须放在最前）
ASM_SRCS = src/vectors.asm src/init.asm src/isr.asm src/display.asm src/keypad.asm src/led_bar.asm src/tables.asm src/main.asm src/calculator.asm

# sdas8051 的 -I 头文件搜索路径
INC_DIRS = inc

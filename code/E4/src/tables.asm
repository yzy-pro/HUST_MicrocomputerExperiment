;--------------------------------------------------------
; tables.asm — ROM 查找表
;   SEG_TAB       : 数字 0-9 的数码管段码
;   LED_BAR_TAB   : D1-D8 进度级别 0-8 的位掩码
;   KEY_REMAP_TAB : 物理扫描码 -> PDF 键号 K0..K15
;--------------------------------------------------------
    .module tables

    .globl SEG_TAB
    .globl LED_BAR_TAB
    .globl KEY_REMAP_TAB

    .area TABLES (CODE)

; 数码管段码，共阴，高电平点亮
; 位序：a=P1.7, b=P1.6, c=P1.5, d=P1.4, e=P1.3, f=P1.2, g=P1.1, dp=P1.0
; 数字 0-9
SEG_TAB:
    .byte 0xFC   ; 0：abcdef
    .byte 0x60   ; 1：bc
    .byte 0xDA   ; 2：abdeg
    .byte 0xF2   ; 3：abcdg
    .byte 0x66   ; 4：bcfg
    .byte 0xB6   ; 5：acdfg
    .byte 0xBE   ; 6：acdefg
    .byte 0xE0   ; 7：abc
    .byte 0xFE   ; 8：abcdefg
    .byte 0xF6   ; 9：abcdfg

; 74HCT164 流水灯位掩码（1=灭，0=亮）
; 下标 = 从 D1 开始点亮的 LED 数量（0=全灭，8=全亮）
LED_BAR_TAB:
    .byte 0xFF   ; 0：全灭
    .byte 0xFE   ; 1：D1 亮
    .byte 0xFC   ; 2：D1-D2 亮
    .byte 0xF8   ; 3：D1-D3 亮
    .byte 0xF0   ; 4：D1-D4 亮
    .byte 0xE0   ; 5：D1-D5 亮
    .byte 0xC0   ; 6：D1-D6 亮
    .byte 0x80   ; 7：D1-D7 亮
    .byte 0x00   ; 8：全亮

; 物理扫描码（row*4+col，0-15）-> PDF 键号 K0..K15。
; 此表来自 src/reference.asm。
; PDF 键号：
;   K10..K13 = F1..F4，K14 = F5，K15 = F6
KEY_REMAP_TAB:
    .byte 0, 4, 8, 12
    .byte 1, 5, 9, 13
    .byte 2, 6,10, 14
    .byte 3, 7,11, 15

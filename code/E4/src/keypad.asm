;--------------------------------------------------------
; keypad.asm — 4x4 矩阵键盘扫描
;
; 硬件连接：
;   行输出：P2.0-P2.3（每次拉低一行）
;   列输入：P2.4-P2.7（低电平表示按下）
;
; 键位映射遵循 src/reference.asm。
; SCAN_KEY 返回 PDF 键号 K0..K15。
;
; 导出函数：
;   SCAN_KEY  — 返回 A=PDF 键号（0-15），无键返回 0xFF
;
; 重映射后的业务含义：
;   K1-K9     -> 批量投放数量
;   K10-K13   -> F1-F4 分类桶按键
;   K14       -> F5，正常模式进入计算器，计算器模式 back
;   K15       -> F6，物业清空
;
; 会改写：ACC, R7, TMP, ROWIDX
;--------------------------------------------------------
    .include "sfr.inc"
    .include "iram.inc"

    .module keypad

    .globl SCAN_KEY

    .globl KEY_REMAP_TAB    ; 定义在 tables.asm

    .area KEY_CODE (CODE)

;--------------------------------------------------------
; SCAN_KEY — 带消抖的完整键盘扫描
; 返回 A = 重映射后的 PDF 键号（0-15），无键返回 0xFF
;--------------------------------------------------------
SCAN_KEY:
    mov  ROWIDX, #0
    mov  P2, #0xFE          ; 第 0 行拉低
    lcall READ_COL
    cjne A, #0xFF, SK_GOT

    mov  ROWIDX, #1
    mov  P2, #0xFD          ; 第 1 行拉低
    lcall READ_COL
    cjne A, #0xFF, SK_GOT

    mov  ROWIDX, #2
    mov  P2, #0xFB          ; 第 2 行拉低
    lcall READ_COL
    cjne A, #0xFF, SK_GOT

    mov  ROWIDX, #3
    mov  P2, #0xF7          ; 第 3 行拉低
    lcall READ_COL
    cjne A, #0xFF, SK_GOT

    mov  P2, #0xFF
    mov  A, #0xFF
    ret

SK_GOT:
    ; 消抖：通过显示刷新等待约 30ms 后重读同一行
    lcall DEBOUNCE_DELAY

    mov  A, ROWIDX
    cjne A, #0, DB_R1
    mov  P2, #0xFE
    sjmp DB_READ
DB_R1:
    cjne A, #1, DB_R2
    mov  P2, #0xFD
    sjmp DB_READ
DB_R2:
    cjne A, #2, DB_R3
    mov  P2, #0xFB
    sjmp DB_READ
DB_R3:
    mov  P2, #0xF7
DB_READ:
    lcall READ_COL
    mov  P2, #0xFF

    cjne A, #0xFF, DB_OK
    mov  A, #0xFF           ; 抖动造成的无效按键
    ret

DB_OK:
    ; 计算扫描码 row*4+col，再查表映射为 PDF 键号
    mov  TMP, A
    mov  A, ROWIDX
    rl   A
    rl   A
    add  A, TMP
    mov  DPTR, #KEY_REMAP_TAB
    movc A, @A+DPTR
    ret

;--------------------------------------------------------
; READ_COL — 读取当前行对应的列输入
; 返回 A = 列号（0-3），无列按下返回 0xFF
;--------------------------------------------------------
READ_COL:
    mov  A, P2
    anl  A, #0xF0
    cjne A, #0xF0, RC_HAS
    mov  A, #0xFF
    ret
RC_HAS:
    jb   0xA4, RC1          ; P2.4
    mov  A, #0
    ret
RC1:
    jb   0xA5, RC2          ; P2.5
    mov  A, #1
    ret
RC2:
    jb   0xA6, RC3          ; P2.6
    mov  A, #2
    ret
RC3:
    jb   0xA7, RC_NONE      ; P2.7
    mov  A, #3
    ret
RC_NONE:
    mov  A, #0xFF
    ret

;--------------------------------------------------------
; DEBOUNCE_DELAY — 通过显示刷新延时约 30ms
;--------------------------------------------------------
DEBOUNCE_DELAY:
    mov  R7, #30
DB1:
    lcall REFRESH_ALL
    djnz R7, DB1
    ret

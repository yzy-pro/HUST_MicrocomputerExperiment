;--------------------------------------------------------
; display.asm — 4 位数码管显示驱动
;
; 硬件：LG3641AH 共阴数码管，段选高电平点亮
;   段选：P1（a=P1.7 .. dp=P1.0）
;   位选：P0.7(B) P0.6(A)
;     BA=00 -> 第 0 位（最左，CAP0）
;     BA=01 -> 第 1 位（CAP1）
;     BA=10 -> 第 2 位（CAP2）
;     BA=11 -> 第 3 位（最右，CAP3）
;
; 导出函数：
;   REFRESH_ALL   — 对 4 位数码管动态扫描一次
;   DELAY_DIG     — 单位数码管保持约 1ms
;
; 使用：BLKFLG, SELBIN, LIDOPEN, ERRBIN, FULLBIN, CAP0..CAP3
; 会改写：ACC, B, DPTR
;--------------------------------------------------------
    .include "sfr.inc"
    .include "iram.inc"

    .module display

    .globl REFRESH_ALL
    .globl DELAY_DIG

    ; tables.asm 中定义的外部符号
    .globl SEG_TAB

    .area DISP_CODE (CODE)

;--------------------------------------------------------
; REFRESH_ALL — 显示 4 位数码管各一次（每次键盘扫描前约调用 40 次）
;
; 垃圾桶容量显示顺序：
;   BA=00 -> CAP0, BA=01 -> CAP1, BA=10 -> CAP2, BA=11 -> CAP3
;--------------------------------------------------------
REFRESH_ALL:
    mov  A, CALCMODE
    jz   REFRESH_NORMAL
    ljmp REFRESH_CALC

REFRESH_NORMAL:
    ; 第 0 位（BA=00）
    mov  A, CAP0
    mov  TMP, #0
    lcall GET_SEG
    mov  B, A
    mov  P1, #0x00          ; 切换位选前先灭段，避免鬼影
    lcall DISPLAY_BLANK_GAP
    anl  P0, #0x3F          ; BA=00
    lcall DISPLAY_BLANK_GAP
    mov  P1, B
    lcall DELAY_DIG
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP

    ; 第 1 位（BA=01）
    mov  A, CAP1
    mov  TMP, #1
    lcall GET_SEG
    mov  B, A
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP
    anl  P0, #0x3F
    orl  P0, #0x40          ; BA=01
    lcall DISPLAY_BLANK_GAP
    mov  P1, B
    lcall DELAY_DIG
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP

    ; 第 2 位（BA=10）
    mov  A, CAP2
    mov  TMP, #2
    lcall GET_SEG
    mov  B, A
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP
    anl  P0, #0x3F
    orl  P0, #0x80          ; BA=10
    lcall DISPLAY_BLANK_GAP
    mov  P1, B
    lcall DELAY_DIG
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP

    ; 第 3 位（BA=11）
    mov  A, CAP3
    mov  TMP, #3
    lcall GET_SEG
    mov  B, A
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP
    anl  P0, #0x3F
    orl  P0, #0xC0          ; BA=11
    lcall DISPLAY_BLANK_GAP
    mov  P1, B
    lcall DELAY_DIG
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP

    ret

REFRESH_CALC:
    ; 逻辑第 3 位（BA=00）
    mov  A, CALCD3
    lcall GET_CALC_SEG
    mov  B, A
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP
    anl  P0, #0x3F
    lcall DISPLAY_BLANK_GAP
    mov  P1, B
    lcall DELAY_DIG
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP

    ; 逻辑第 2 位（BA=01）
    mov  A, CALCD2
    lcall GET_CALC_SEG
    mov  B, A
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP
    anl  P0, #0x3F
    orl  P0, #0x40
    lcall DISPLAY_BLANK_GAP
    mov  P1, B
    lcall DELAY_DIG
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP

    ; 逻辑第 1 位（BA=10）
    mov  A, CALCD1
    lcall GET_CALC_SEG
    mov  B, A
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP
    anl  P0, #0x3F
    orl  P0, #0x80
    lcall DISPLAY_BLANK_GAP
    mov  P1, B
    lcall DELAY_DIG
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP

    ; 逻辑第 0 位（BA=11）
    mov  A, CALCD0
    lcall GET_CALC_SEG
    mov  B, A
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP
    anl  P0, #0x3F
    orl  P0, #0xC0
    lcall DISPLAY_BLANK_GAP
    mov  P1, B
    lcall DELAY_DIG
    mov  P1, #0x00
    lcall DISPLAY_BLANK_GAP

    ret

;--------------------------------------------------------
; GET_SEG — 获取 TMP 指定位置的段码
;   输入：A = 容量值（0-9）
;         TMP = 数码管位置（0-3）
;   输出：A = 写入 P1 的段码
;
; 覆盖显示优先级（从高到低）：
;   1. ERRBIN == TMP   -> 显示 E（批量投放错误）
;   2. FULLBIN == TMP  -> 显示 F（满桶提示）
;   3. LIDOPEN 且 SELBIN == TMP 且 BLKFLG == 0 -> 熄灭形成闪烁
;   4. 正常显示 SEG_TAB 中的数字段码
;--------------------------------------------------------
GET_SEG:
    push ACC                ; 保存容量值

    ; 检查 E 覆盖显示
    mov  A, ERRBIN
    cjne A, TMP, GS_CHECK_FULL
    pop  ACC
    mov  A, #0x9E           ; E 的段码
    ret

GS_CHECK_FULL:
    ; 检查 F 覆盖显示
    mov  A, FULLBIN
    cjne A, TMP, GS_CHECK_BLINK
    pop  ACC
    mov  A, #0x8E           ; F 的段码
    ret

GS_CHECK_BLINK:
    ; 检查开盖闪烁的熄灭阶段
    mov  A, LIDOPEN
    jz   GS_NORMAL
    mov  A, SELBIN
    cjne A, TMP, GS_NORMAL
    mov  A, BLKFLG
    jnz  GS_NORMAL
    pop  ACC
    mov  A, #0x00           ; 闪烁熄灭阶段显示空白
    ret

GS_NORMAL:
    pop  ACC                ; 恢复容量值
    mov  DPTR, #SEG_TAB
    movc A, @A+DPTR
    ret

;--------------------------------------------------------
; GET_CALC_SEG — 计算器显示缓存转段码
;   输入：A = 0-9 数字，0x0A=空白，0x0B='-'，0x0C='E'
;   输出：A = 写入 P1 的段码
;--------------------------------------------------------
GET_CALC_SEG:
    cjne A, #0x0A, GCS_MINUS
    mov  A, #0x00
    ret
GCS_MINUS:
    cjne A, #0x0B, GCS_ERR
    mov  A, #0x02           ; 仅 g 段，显示 '-'
    ret
GCS_ERR:
    cjne A, #0x0C, GCS_DIGIT
    mov  A, #0x9E           ; E
    ret
GCS_DIGIT:
    mov  DPTR, #SEG_TAB
    movc A, @A+DPTR
    ret

;--------------------------------------------------------
; DELAY_DIG — 保持当前位约 1ms（24.5MHz 下）
;--------------------------------------------------------
DELAY_DIG:
    mov  R6, #8
DD1:
    mov  R5, #180
DD2:
    djnz R5, DD2
    djnz R6, DD1
    ret

;--------------------------------------------------------
; DISPLAY_BLANK_GAP — 段选关闭后的短消隐，释放残留亮度
;--------------------------------------------------------
DISPLAY_BLANK_GAP:
    mov  R4, #18
DBG1:
    djnz R4, DBG1
    ret

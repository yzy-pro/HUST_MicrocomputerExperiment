;--------------------------------------------------------
; led_bar.asm — D1-D8 流水灯进度条驱动（经 74HCT164）
;
; 硬件连接：
;   74HCT164 移位寄存器：DATA=P3.3，CLK=P3.4
;   Q1=D1 .. Q8=D8，0=亮，1=灭
;   D9 为独立指示灯，接 P0.0，0=亮，1=灭
;
; 导出函数：
;   UPDATE_LED_BAR  — 根据桶盖倒计时计算 LEDREG，变化时移位输出
;   SHIFT_LED_BAR   — 将 LEDREG 输出到 74HCT164（移位期间关闭中断）
;
; LED 级别表（LED_BAR_TAB，位于 tables.asm）：
;   下标 0..8，表值为 D1..D8 位掩码（1=灭，0=亮，从高位送出）
;   0 -> 0xFF（全灭），8 -> 0x00（全亮）
;--------------------------------------------------------
    .include "sfr.inc"
    .include "iram.inc"

    .module led_bar

    .globl UPDATE_LED_BAR
    .globl SHIFT_LED_BAR

    .globl LED_BAR_TAB      ; 定义在 tables.asm

    .area LED_CODE (CODE)

;--------------------------------------------------------
; UPDATE_LED_BAR
; 桶盖关闭：强制 D1-D8 全灭（若已经全灭则不重复移位）。
; 桶盖打开：将剩余时间（LIDHI:LIDLO）映射为 0-8 格进度。
; D9 由 init/isr 管理，开盖时点亮。
;--------------------------------------------------------
UPDATE_LED_BAR:
    mov  A, LIDOPEN
    jnz  ULB_OPEN

    ; 桶盖关闭：流水灯全灭
    mov  A, LASTBAR
    cjne A, #0xFF, ULB_CLOSE_APPLY
    ret                     ; 已经全灭，无需更新
ULB_CLOSE_APPLY:
    mov  LEDREG,  #0xFF
    mov  LASTBAR, #0xFF
    lcall SHIFT_LED_BAR
    ret

ULB_OPEN:
    ; 将 LIDHI:LIDLO（0-8000ms）映射为 0-8 格
    ; 阈值：7000,6000,5000,4000,3000,2000,1000,1,0
    ; 使用 16 位比较：先比较高字节，再比较低字节

    ; 是否 >= 7000 (0x1B58)
    mov  A, LIDHI
    clr  C
    subb A, #0x1B
    jc   ULB_LE7
    jnz  ULB_GE8
    mov  A, LIDLO
    clr  C
    subb A, #0x58
    jc   ULB_LE7
ULB_GE8:
    mov  A, #8
    ljmp ULB_IDX

ULB_LE7:
    ; 是否 >= 6000 (0x1770)
    mov  A, LIDHI
    clr  C
    subb A, #0x17
    jc   ULB_LE6
    jnz  ULB_GE7
    mov  A, LIDLO
    clr  C
    subb A, #0x70
    jc   ULB_LE6
ULB_GE7:
    mov  A, #7
    ljmp ULB_IDX

ULB_LE6:
    ; 是否 >= 5000 (0x1388)
    mov  A, LIDHI
    clr  C
    subb A, #0x13
    jc   ULB_LE5
    jnz  ULB_GE6
    mov  A, LIDLO
    clr  C
    subb A, #0x88
    jc   ULB_LE5
ULB_GE6:
    mov  A, #6
    ljmp ULB_IDX

ULB_LE5:
    ; 是否 >= 4000 (0x0FA0)
    mov  A, LIDHI
    clr  C
    subb A, #0x0F
    jc   ULB_LE4
    jnz  ULB_GE5
    mov  A, LIDLO
    clr  C
    subb A, #0xA0
    jc   ULB_LE4
ULB_GE5:
    mov  A, #5
    ljmp ULB_IDX

ULB_LE4:
    ; 是否 >= 3000 (0x0BB8)
    mov  A, LIDHI
    clr  C
    subb A, #0x0B
    jc   ULB_LE3
    jnz  ULB_GE4
    mov  A, LIDLO
    clr  C
    subb A, #0xB8
    jc   ULB_LE3
ULB_GE4:
    mov  A, #4
    ljmp ULB_IDX

ULB_LE3:
    ; 是否 >= 2000 (0x07D0)
    mov  A, LIDHI
    clr  C
    subb A, #0x07
    jc   ULB_LE2
    jnz  ULB_GE3
    mov  A, LIDLO
    clr  C
    subb A, #0xD0
    jc   ULB_LE2
ULB_GE3:
    mov  A, #3
    ljmp ULB_IDX

ULB_LE2:
    ; 是否 >= 1000 (0x03E8)
    mov  A, LIDHI
    clr  C
    subb A, #0x03
    jc   ULB_LE1
    jnz  ULB_GE2
    mov  A, LIDLO
    clr  C
    subb A, #0xE8
    jc   ULB_LE1
ULB_GE2:
    mov  A, #2
    ljmp ULB_IDX

ULB_LE1:
    mov  A, LIDHI
    orl  A, LIDLO
    jz   ULB_ZERO
    mov  A, #1
    ljmp ULB_IDX
ULB_ZERO:
    mov  A, #0

ULB_IDX:
    ; A = 级别 0-8，查表得到位掩码
    mov  DPTR, #LED_BAR_TAB
    movc A, @A+DPTR

ULB_APPLY:
    mov  LEDREG, A
    xrl  A, LASTBAR
    jz   ULB_RET            ; 无变化，跳过移位
    mov  A, LEDREG
    mov  LASTBAR, A
    lcall SHIFT_LED_BAR
ULB_RET:
    ret

;--------------------------------------------------------
; SHIFT_LED_BAR — 将 LEDREG 从最高位开始送入 74HCT164
; 移位期间关闭中断，避免时钟被打断。
;--------------------------------------------------------
SHIFT_LED_BAR:
    clr  EA                 ; 关闭中断
    mov  A, LEDREG
    mov  R0, #8
SLB_LP:
    mov  C, ACC.7
    mov  LEDDAT, C          ; P3.3 = 数据位
    setb LEDCLK             ; P3.4 产生上升沿
    nop
    clr  LEDCLK
    rl   A
    djnz R0, SLB_LP
    setb EA                 ; 重新打开中断
    ret

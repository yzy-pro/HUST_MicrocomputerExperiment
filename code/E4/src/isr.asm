;--------------------------------------------------------
; isr.asm — 中断服务程序
;   EXT0_ISR  : Kint 提前关盖键（INT0，下降沿触发）
;   TIMER0_ISR: 1ms 系统节拍（Timer0 溢出）
;--------------------------------------------------------
    .include "sfr.inc"
    .include "iram.inc"

    .module isr

    .globl EXT0_ISR
    .globl TIMER0_ISR

    .area ISR_CODE (CODE)

;--------------------------------------------------------
; EXT0_ISR — 提前关盖（Kint 按键，P0.1）
; 立即关闭桶盖：清除 LIDOPEN，复位倒计时，熄灭 D9。
;--------------------------------------------------------
EXT0_ISR:
    push ACC
    push PSW

    mov  A, CALCMODE
    jz   EX0_NORMAL

    ; 计算器模式下，Kint 作为退出键。
    mov  CALCMODE,  #0x00
    mov  CALCSTATE, #0x00
    mov  CALCOP,    #0x00
    mov  OP1,       #0x00
    mov  OP2,       #0x00
    mov  DIGCNT,    #0x00
    mov  CALCNEG,   #0x00
    sjmp EX0_DONE

EX0_NORMAL:
    mov  A, LIDOPEN
    jz   EX0_DONE          ; 桶盖已关闭时直接忽略

    mov  LIDOPEN, #0x00
    mov  SELBIN,  #0xFF
    mov  LIDLO,   #0x00
    mov  LIDHI,   #0x00
    mov  BLKDIV,  #0x00
    mov  BLKFLG,  #0x00
    setb D9_LED             ; D9 熄灭

EX0_DONE:
    pop  PSW
    pop  ACC
    reti

;--------------------------------------------------------
; TIMER0_ISR — 1ms 系统节拍
; 重装 TH0/TL0，并维护桶盖倒计时、闪烁标志和蜂鸣/提示倒计时。
;--------------------------------------------------------
TIMER0_ISR:
    push ACC
    push PSW

    ; 重装 1ms 初值：65536 - (24500000/12/1000) = 63494 = 0xF806
    mov  TH0, #0xF8
    mov  TL0, #0x06

    ;--- 桶盖倒计时（LIDHI:LIDLO，单位 ms） ---
    mov  A, LIDLO
    orl  A, LIDHI
    jz   T0_SKIP_LID

    mov  A, LIDLO
    jnz  T0_DEC_LO
    dec  LIDHI
T0_DEC_LO:
    dec  LIDLO

    mov  A, LIDLO
    orl  A, LIDHI
    jnz  T0_SKIP_LID

    ; 倒计时归零：自动关盖
    mov  LIDOPEN, #0x00
    mov  SELBIN,  #0xFF
    setb D9_LED             ; D9 熄灭

T0_SKIP_LID:

    ;--- 5Hz 闪烁标志（每 100ms 翻转一次） ---
    inc  BLKDIV
    mov  A, BLKDIV
    cjne A, #100, T0_HINT
    mov  BLKDIV, #0x00
    mov  A, BLKFLG
    xrl  A, #0x01
    mov  BLKFLG, A

T0_HINT:
    ;--- 报警倒计时（HINTHI:HINTLO，单位 ms） ---
    ; 归零后关闭蜂鸣器，并清除 F/E 覆盖显示
    mov  A, HINTLO
    orl  A, HINTHI
    jz   T0_END

    mov  A, HINTLO
    jnz  T0_DEC_HL
    dec  HINTHI
T0_DEC_HL:
    dec  HINTLO

    mov  A, HINTLO
    orl  A, HINTHI
    jnz  T0_END

    ; 报警结束：关闭蜂鸣器，清除 F/E 显示
    clr  BUZZER
    mov  FULLBIN, #0xFF
    mov  ERRBIN,  #0xFF

T0_END:
    pop  PSW
    pop  ACC
    reti

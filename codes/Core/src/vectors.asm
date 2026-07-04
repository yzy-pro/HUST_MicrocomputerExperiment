;--------------------------------------------------------
; vectors.asm — 中断向量表与复位入口
; 必须最先链接，使代码从 0x0000 开始
;--------------------------------------------------------
    .include "sfr.inc"

    .module vectors

    .area VECTOR (ABS,CODE)

    ; 复位向量 @ 0x0000
    .org 0x0000
    ljmp START

    ; INT0（外部中断 0，Kint 提前关盖键）@ 0x0003
    .org 0x0003
    ljmp EXT0_ISR

    ; Timer0 溢出中断（1ms 节拍）@ 0x000B
    .org 0x000B
    ljmp TIMER0_ISR

    ; Timer1 和 EXT1 未使用，填充到 0x0100
    .org 0x0100
    ljmp START          ; 保护入口：异常跳转到此处也重新启动

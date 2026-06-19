;-------------------------------------------------------------------------------
; Interrupt vectors
;-------------------------------------------------------------------------------
            CSEG
            ORG 0000H
            LJMP START

            ORG 0003H          ; External interrupt 0, P0.1 on this EVM design
            LJMP INT0_ISR

            ORG 000BH          ; Timer0 interrupt
            LJMP TIMER0_ISR

            ORG 002BH          ; Timer2 interrupt, exact 1 ms game time base
            LJMP TIMER2_ISR


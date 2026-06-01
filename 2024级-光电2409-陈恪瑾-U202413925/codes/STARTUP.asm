; AT89C52(12MHz) 智能垃圾桶控制程序

; 
KEY_BIN0        BIT     P2.7
KEY_BIN1        BIT     P2.6
KEY_BIN2        BIT     P2.5
KEY_BIN3        BIT     P2.4
KEY_CLEAR       BIT     P2.3
KEY_EARLY       BIT     P3.2

FULL_FLAGS      DATA    020H
TMP_DATA        DATA    021H
MS_CNT_L        DATA    022H
MS_CNT_H        DATA    023H
SEC_LEFT        DATA    024H
PROGRESS        DATA    025H
ACTIVE_MASK     DATA    026H
STATE           DATA    027H

OPENING         BIT     STATE.0

; 中断向量
                ORG     0000H
                LJMP    START

                ORG     0003H
                LJMP    EXT0_ISR

                ORG     000BH
                LJMP    TIMER0_ISR

; setup函数
                ORG     0030H
START:
                MOV     P1, #0FFH
                MOV     P0, #000H
                MOV     P2, #0FFH

                MOV     FULL_FLAGS, #00H
                LCALL   UPDATE_FULL_LED

                MOV     TMOD, #11H
                LCALL   T0_RELOAD_1MS
                CLR     TR0
                CLR     TF0
                SETB    ET0
                SETB    IT0
                SETB    EX0
                SETB    EA
                SETB    TR1

                CLR     OPENING
                MOV     ACTIVE_MASK, #00H
                MOV     SEC_LEFT, #00H
                MOV     PROGRESS, #0FFH

                LCALL   RAND_0_9
                MOV     R0, A
                LCALL   RAND_0_9
                MOV     R1, A
                LCALL   RAND_0_9
                MOV     R2, A
                LCALL   RAND_0_9
                MOV     R3, A

; loop函数，轮询处理按键
MAIN_LOOP:
                JNB     KEY_CLEAR, DO_CLEAR

                JNB     KEY_BIN0, KEY0_HIT
                JNB     KEY_BIN1, KEY1_HIT
                JNB     KEY_BIN2, KEY2_HIT
                JNB     KEY_BIN3, KEY3_HIT
                SJMP    MAIN_LOOP

KEY0_HIT:
                LJMP    TRY_BIN0
KEY1_HIT:
                LJMP    TRY_BIN1
KEY2_HIT:
                LJMP    TRY_BIN2
KEY3_HIT:
                LJMP    TRY_BIN3

; 清理垃圾桶函数，重置容量和状态
DO_CLEAR:
                MOV     R0, #09H
                MOV     R1, #09H
                MOV     R2, #09H
                MOV     R3, #09H
                MOV     FULL_FLAGS, #00H
                LCALL   UPDATE_FULL_LED
                LCALL   WAIT_RELEASE
                LJMP    MAIN_LOOP

; 打开垃圾桶函数，判断满载，再尝试打开，其余垃圾桶同理
TRY_BIN0:
                MOV     A, FULL_FLAGS
                ANL     A, #01H
                JNZ     BIN0_DENY

                MOV     A, R0
                JZ      BIN0_MARK_FULL
                DEC     R0
                MOV     A, R0
                JNZ     BIN0_OPEN
                ORL     FULL_FLAGS, #01H
                LCALL   UPDATE_FULL_LED

BIN0_OPEN:
                MOV     A, #01H
                LCALL   OPEN_BIN_8S
                LCALL   WAIT_RELEASE
                LJMP    MAIN_LOOP

BIN0_MARK_FULL:
                ORL     FULL_FLAGS, #01H
                LCALL   UPDATE_FULL_LED
BIN0_DENY:
                LCALL   WAIT_RELEASE
                LJMP    MAIN_LOOP

TRY_BIN1:
                MOV     A, FULL_FLAGS
                ANL     A, #02H
                JNZ     BIN1_DENY

                MOV     A, R1
                JZ      BIN1_MARK_FULL
                DEC     R1
                MOV     A, R1
                JNZ     BIN1_OPEN
                ORL     FULL_FLAGS, #02H
                LCALL   UPDATE_FULL_LED

BIN1_OPEN:
                MOV     A, #02H
                LCALL   OPEN_BIN_8S
                LCALL   WAIT_RELEASE
                LJMP    MAIN_LOOP

BIN1_MARK_FULL:
                ORL     FULL_FLAGS, #02H
                LCALL   UPDATE_FULL_LED
BIN1_DENY:
                LCALL   WAIT_RELEASE
                LJMP    MAIN_LOOP

TRY_BIN2:
                MOV     A, FULL_FLAGS
                ANL     A, #04H
                JNZ     BIN2_DENY

                MOV     A, R2
                JZ      BIN2_MARK_FULL
                DEC     R2
                MOV     A, R2
                JNZ     BIN2_OPEN
                ORL     FULL_FLAGS, #04H
                LCALL   UPDATE_FULL_LED

BIN2_OPEN:
                MOV     A, #04H
                LCALL   OPEN_BIN_8S
                LCALL   WAIT_RELEASE
                LJMP    MAIN_LOOP

BIN2_MARK_FULL:
                ORL     FULL_FLAGS, #04H
                LCALL   UPDATE_FULL_LED
BIN2_DENY:
                LCALL   WAIT_RELEASE
                LJMP    MAIN_LOOP

TRY_BIN3:
                MOV     A, FULL_FLAGS
                ANL     A, #08H
                JNZ     BIN3_DENY

                MOV     A, R3
                JZ      BIN3_MARK_FULL
                DEC     R3
                MOV     A, R3
                JNZ     BIN3_OPEN
                ORL     FULL_FLAGS, #08H
                LCALL   UPDATE_FULL_LED

BIN3_OPEN:
                MOV     A, #08H
                LCALL   OPEN_BIN_8S
                LCALL   WAIT_RELEASE
                LJMP    MAIN_LOOP

BIN3_MARK_FULL:
                ORL     FULL_FLAGS, #08H
                LCALL   UPDATE_FULL_LED
BIN3_DENY:
                LCALL   WAIT_RELEASE
                LJMP    MAIN_LOOP

; 开盖计时器
OPEN_BIN_8S:
                MOV     ACTIVE_MASK, A
                CPL     A
                ANL     P1, A

                MOV     PROGRESS, #0FFH
                MOV     P0, #0FFH
                MOV     SEC_LEFT, #08H
                MOV     MS_CNT_L, #0E8H
                MOV     MS_CNT_H, #03H

                SETB    OPENING
                LCALL   T0_RELOAD_1MS
                CLR     TF0
                SETB    TR0

OPEN_WAIT:
                JB      OPENING, OPEN_WAIT
                RET

; 外部中断0：提前关盖（KEY_EARLY=P3.2，低电平触发）
EXT0_ISR:
                PUSH    ACC
                PUSH    PSW
                JNB     OPENING, EXT0_ISR_EXIT
                LCALL   FORCE_CLOSE
EXT0_ISR_EXIT:
                POP     PSW
                POP     ACC
                RETI

; 1ms延时中断
TIMER0_ISR:
                PUSH    ACC
                PUSH    PSW

                LCALL   T0_RELOAD_1MS
                JNB     OPENING, T0_ISR_EXIT

                MOV     A, MS_CNT_L
                JNZ     MS_DEC_LOW

                MOV     A, MS_CNT_H
                JZ      ONE_SECOND_ELAPSED
                DEC     MS_CNT_H
                MOV     MS_CNT_L, #0FFH
                SJMP    T0_ISR_EXIT

MS_DEC_LOW:
                DEC     MS_CNT_L
                MOV     A, MS_CNT_L
                JNZ     T0_ISR_EXIT
                MOV     A, MS_CNT_H
                JNZ     T0_ISR_EXIT

ONE_SECOND_ELAPSED:
                MOV     MS_CNT_L, #0E8H
                MOV     MS_CNT_H, #03H

                DEC     SEC_LEFT
                CLR     C
                MOV     A, PROGRESS
                RRC     A
                MOV     PROGRESS, A
                MOV     P0, A

                MOV     A, SEC_LEFT
                JNZ     T0_ISR_EXIT
                LCALL   FORCE_CLOSE

T0_ISR_EXIT:
                POP     PSW
                POP     ACC
                RETI

; 强制关盖
FORCE_CLOSE:
                CLR     TR0
                MOV     A, ACTIVE_MASK
                ORL     P1, A
                MOV     ACTIVE_MASK, #00H
                CLR     OPENING
                MOV     P0, #000H
                RET

T0_RELOAD_1MS:
                ; 12MHz 下定时器计数周期 1us，1ms 需 1000 次计数
                ; 重装值 = 65536 - 1000 = FC18H
                MOV     TH0, #0FCH
                MOV     TL0, #018H
                RET


; 随机数生成器
RAND_0_9:
                MOV     A, TL1
                XRL     A, TH1
                XRL     A, #05AH
                RL      A
                XRL     A, #01DH
                RR      A
                ANL     A, #01FH

RAND_MOD10:
                CLR     C
                SUBB    A, #0AH
                JNC     RAND_MOD10
                ADD     A, #0AH
                RET

UPDATE_FULL_LED:
                ; 释放 P3.2 作为 INT0 键输入，满载灯改用 P3.0/P3.1/P3.4/P3.5
                MOV     A, FULL_FLAGS
                ANL     A, #03H
                MOV     TMP_DATA, A

                MOV     A, FULL_FLAGS
                ANL     A, #0CH
                RL      A
                RL      A
                ORL     A, TMP_DATA
                MOV     TMP_DATA, A

                MOV     A, P3
                ANL     A, #0CCH
                ORL     A, TMP_DATA
                MOV     P3, A
                RET

WAIT_RELEASE:
                MOV     A, P2
                ANL     A, #0F8H
                CJNE    A, #0F8H, WAIT_RELEASE
                RET

                END

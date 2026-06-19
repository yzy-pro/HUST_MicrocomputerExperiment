;-------------------------------------------------------------------------------
; led_bar.asm - 74HCT164 LED output and PWM service
;-------------------------------------------------------------------------------
LED_PWM_SERVICE:
            INC led_pwm
            MOV A, led_pwm
            ANL A, #03H              ; 1/4 duty cycle, about 25% brightness
            JNZ LED_PWM_OFF
            MOV A, led_pattern
            SJMP LED_PWM_WRITE
LED_PWM_OFF:
            MOV A, #0FFH             ; active-low LEDs off
LED_PWM_WRITE:
            PUSH 07H
            LCALL LED_WRITE_A
            POP 07H
            RET

LED_WRITE_A:
            MOV R7, #08H
LED_BIT_LOOP:
            RLC A
            MOV P3.3, C
            SETB P3.4
            NOP
            CLR P3.4
            DJNZ R7, LED_BIT_LOOP
            RET

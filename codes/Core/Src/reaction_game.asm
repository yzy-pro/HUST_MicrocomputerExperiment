;-------------------------------------------------------------------------------
;  File      : reaction_game.asm
;  Target    : C8051F310 EVM
;  Project   : Reaction and Rhythm Challenge Trainer
;  Author    : PBL Group Template
;  Date      : 2026-06-17
;
;  This top-level file keeps the original single-file build entry while the
;  implementation is organized like codes/Core/template:
;    ../Inc/reaction_game.inc  - shared constants and internal RAM symbols
;    vectors.asm              - reset and interrupt vectors
;    init.asm                 - MCU and peripheral initialization
;    main.asm                 - main loop dispatcher
;    game_logic.asm           - game state machine and mode handlers
;    isr.asm                  - Timer0/Timer2/INT0 interrupt services
;    display.asm              - 4-digit seven-segment display routines
;    keypad.asm               - matrix keypad and KINT scanning
;    random_score.asm         - random seed and best-score helpers
;    led_bar.asm              - 74HCT164 LED output and PWM service
;    uart.asm                 - UART output helpers
;    tables.asm               - ROM lookup tables and strings
;
;  Hardware resource mapping from C8051F310EVM guide:
;    4-digit 7-seg segments : P1.7..P1.0 = a,b,c,d,e,f,g,dp, high active
;    4-digit 7-seg select   : P0.7=B, P0.6=A
;    4x4 keypad rows        : P2.0..P2.3 output scan lines, KO.0..KO.3
;    4x4 keypad columns     : P2.4..P2.7 input columns, KI.0..KI.3
;    Buzzer                 : P3.1, high active
;    LED array via 74HCT164 : P3.3 = DAT_IN, P3.4 = CLK, LED is active-low
;    External trigger key   : P0.1, low active
;    UART0                  : P0.4 = TXD, P0.5 = RXD, J3 uses 3.3V TTL level
;-------------------------------------------------------------------------------

$include (../Inc/reaction_game.inc)

$include (vectors.asm)
$include (init.asm)
$include (main.asm)
$include (game_logic.asm)
$include (isr.asm)
$include (display.asm)
$include (keypad.asm)
$include (random_score.asm)
$include (led_bar.asm)
$include (uart.asm)
$include (tables.asm)

            END

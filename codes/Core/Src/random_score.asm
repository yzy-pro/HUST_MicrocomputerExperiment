;-------------------------------------------------------------------------------
; random_score.asm - random seed and best-score helpers
;-------------------------------------------------------------------------------
MAKE_RANDOM:
            MOV A, rand_seed
            XRL A, TL0
            RL A
            ADD A, #03DH
            MOV rand_seed, A
            RET

UPDATE_BEST:
            ; smaller reaction time is better. best initialized to FFFF.
            MOV A, score_hi
            CLR C
            SUBB A, best_hi
            JC BEST_UPDATE
            JNZ BEST_DONE
            MOV A, score_lo
            CLR C
            SUBB A, best_lo
            JC BEST_UPDATE
            SJMP BEST_DONE
BEST_UPDATE:
            MOV best_hi, score_hi
            MOV best_lo, score_lo
BEST_DONE:
            RET

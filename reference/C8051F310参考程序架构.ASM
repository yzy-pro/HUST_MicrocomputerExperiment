$include (C8051F310.inc)

		ORG 0000H
		LJMP START
		
		ORG 000BH
		LJMP ITOP
		
		ORG 0100H
START:	LCALL INIT_DEVICE

		;========用户主程序代码区=============	
		




		;========用户子程序代码区=============
		ORG 0200H
DLY:

			RET
		
		
		;========中断服务程序================
		ORG 0300H
ITOP:

			RETI					
	

		;========配置向导生成的代码区=========
		ORG 0400H

; Peripheral specific initialization functions,
; Called from the Init_Device label
PCA_Init:
    anl  PCA0MD,    #0BFh
    mov  PCA0MD,    #000h
    ret

Port_IO_Init:
    mov  P0MDOUT,   #0C0h
    mov  P1MDOUT,   #0FFh
    mov  XBR1,      #040h
    ret

; Initialization function for device,
; Call Init_Device from your main program
Init_Device:
    lcall PCA_Init
    lcall Port_IO_Init
    ret
	
	
	;========数码管段码表=================
				ORG 0500H
;TABLE:	DB 3FH,06H,5BH,4FH,66H,6DH,7DH,07H,7FH,6FH;共阴极数码管0~9段码表
TABLE:	DB 0FCH,60H,0DAH,0F2H,66H,0B6H,0BEH,0E0H,0FEH,0E6H;共阴极数码管0~9段码表	
END
		
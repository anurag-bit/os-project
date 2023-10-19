org 0x7C00
bits 16





main:
    ; setup data segments
    mov ax, 0               ;can't write to ds/es directly 
    mov ds, ax 
    mov es, ax

    ; setup stack 
    mov ss, ax
    mov sp, 0x7C00  ; stack grows down


    hlt

.halt:
    jmp .halt
times 510-($-$$) db 0
dw 0AA55h
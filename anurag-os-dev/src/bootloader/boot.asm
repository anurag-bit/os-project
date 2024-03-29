org 0x7C00
bits 16

%define     ENDL   0x0D, 0x0A

;
;FAT12 header 
;

jmp short start
nop 

bdb_oem:                              db 'MSWIN4.1'             ; 8 bytes 
bdb_bytes_per_sector:                 dw 512                    ;
bdb_sectors_per_clusters:             db 1                      ;
bdb_reserved_sectors:                 dw 1
bdb_fat_count:                        db 2 
bdb_dir_entries_count:                dw 0E0h
bdb_total_sectors:                    dw 2880                   ; 2880*512 = 1.44megabytes
bdb_media_descriptor_type:            db 0F0h                   ; f0 =m 3.5" floppy disk 
bdb_sectors_per_fat:                  dw 9                      ; 9 sectos/fat 
bdb_sectors_per_track:                dw 18 
bdb_heads:                            dw 2 
bdb_hidden_sectors:                   dd 0
bdb_large_sector_count:               dd 0 

;extended Boot record 
ebr_drive_number:                     db 0                      ; 0x00 floppy, 0x80 hdd, useless
                                      db 0                      ; reserved
ebr_signature:                        db 29h
ebr_volume_id:                        db 12h, 34h, 56h, 78h     ; serial does not mean to our purpose.
ebr_volume_label:                     db 'ANURAG OS'            ; 11 bytes, padded with space 
ebr_system_id:                        db 'FAT12 '               ; 8 bytes                      



;
;code here
;
start:
    jmp main 

;
;
;Prints a String to the screen.
;Params:
; - ds:si points to strings
;
;
puts:
    push si 
    push ax 
    push bx 

.loop:
    lodsb           ;loads the next character in al 
    or al, al       ;verify if next character is null?
    jz .done
    

    mov ah, 0x0E    ;call bios interrupt routine
    mov bh, 0          
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si
    ret


main:
    ; setup data segments
    mov ax, 0               ;can't write to ds/es directly 
    mov ds, ax 
    mov es, ax

    ; setup stack 
    mov ss, ax
    mov sp, 0x7C00  ; stack grows downwards from where loaded into memory

    ; read something from floppy disk 
    ; BIOS  should set DL to drive number 
    mov [ebr_drive_number], dl 

    mov ax, 1                ; LBA-1, second sector from disk 
    mov cl, 1                ; 1 sector to read 
    mov bx, 0x7E00           ; data should be after the bootloader   
    call disk_read




    ; preparing delivery of print payload
    ; print message 
    mov si,  msg_hello
    call puts  
    
    cli
    hlt

floppy_error:
        mov si, msg_read_failed
        call puts 
        jmp wait_key_and_reboot


wait_key_and_reboot:
        mov ah, 0 
        int 16h                         ; wait for keypress
        jmp 0FFFFh:0                    ; jump to beginning of BIOS, should reboot
        

.halt:
    cli                                 ; disable interrupts, this way we can't get out of of "halt"  state 
    hlt 



;
;Disk routines
;
; Converts an LBA address to a CHS address
; Parameters:
; - ax: LBA address
; Returns:
; - cx [bits 0-5]: sector nu mber
; - cx [bits 6-15]: cylinder
; dh: head




lba_to_chs:

    push ax
    push dx    

    xor dx, dx                                  ; dx = 0
    div word [bdb_sectors_per_track]            ; ax = LBA / Sectors PerTrack
                                                ; dx = LBA % SectorsPerTrack

    inc dx                                      ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                                  ; cx = sector

    xor dx, dx                                  ; dx = 0
    div word [bdb_heads]                        ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                                ; dx = (LBA / SectorsPerTrack) % Heads = head

    mov dh, dl                                  ; dh = head
    mov ch, al                                  ; ch = cylinder (lower 8 bits)  
    shl ah, 6 
    or cl, ah                                   ; put upper 2 bits of cylinder in CL

    pop ax 
    mov dl, al                                  ; restore DL 
    pop ax
    ret 



;
;
;Reads sectors from a disk 
;Parameters:
;       - ax: LBA address
;       - cl: number of sectors to read(upto 128) 
;       - dl: drive number 
;       - es:bs: memory address where to store  read data.
;

disk_read:

    push ax                     ; save registers will modify  
    push bx 
    push cx
    push dx 
    push di 



    push cx                     ; temporarily save CL (number of sectors to read) 
    call lba_to_chs             ; compute CHS
    pop  ax                     ; AL = number of sectors to read    

    mov  ah, 02h                   
    mov  di, 3                  ; retry count


.retry:
    pusha                      ; save all registers, we don't know what bios modifies 
    stc                         ; set carry flag, some BIOS'es don't set it
    int  13h                    ; carry flag cleared = succes 
    jnc .done                   ; jump if carry not set 

   ;read failed 
    popa                     ;  
    call disk_reset


    dec  di 
    test di, di 
    jnz .retry

.fail:
    jmp floppy_error

.done:
    popa


    pop  di 
    pop  dx 
    pop  cx 
    pop  bx 
    pop  ax                         ; restore registers modified 
    ret 

;
;Resets disk controller 
;Parameters:
;   dl: drive number
;
;
disk_reset:
    pusha
    mov ah, 0 
    stc
    int 13h
    jc floppy_error 
    popa
    ret

msg_hello:          db  'Trantor: waiting for peripheral enumeration', ENDL, 0
msg_read_failed:    db  'Reading from disk sda0',  ENDL, 0 


times 510-($-$$) db 0
dw 0AA55h

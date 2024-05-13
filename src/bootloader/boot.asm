org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 header
; 
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'NANOBYTE OS'        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes

;
; Code goes here
;

start:
   jmp main

puts:
  ;save registers we will modify
  push si
  push ax

.loop:
  lodsb         ;loads next char from si into al
  or al, al     ;checks if next char is null
  jz .done

  mov ah, 0x0e    ;call bios interrupt
  int 0x10

  jmp .loop

.done:
   pop ax
   pop si
   ret

main: 

  ;setup data segments
  mov ax, 0    ;can't write to ds/es directly
  mov ds, ax
  mov es, ax

  ;setup stack
  mov ss, ax
  mov sp, 0x7C00  ;stack grows downwards from where we are loaded into memory

  ;print message
  mov si, msg_hello
  call puts
   
  hlt

.halt: 
    jmp .halt

;
; Disk routines
;

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;

lba_to_chs:

 xor dx,dx                          ;dx = 0
 div word [bdb_sectors_per_track]   ;ax = LBA / SectorsPerTrack
                                    ;dx = LBA % SectorsPerTrack
 inc dx                             ;dx = (LBA % SectorsPerTrack + 1) = sector
 mov cx,dx                          ;cx = sector

 xor dx,dx                          ;dx = 0
 div word [bdb_heads]               ;ax = (LBA / SectorsPerTrack / Heads) = cylinder
                                    ;dx = (LBA / SectorsPerTrack) % Heads = head
 mov dh, dl                         ;dh = head 
 mov ch, al                         ;ch = cylinder (lower 8 bits)
 shl ah, 6
 or cl, ah                          ;put upper 2 bits of cylinder in CL

 pop ax
 mov dl, al                         ;restore DL
 pop ax
 ret


msg_hello: db 'Hello world', ENDL, 0 ;null terminated string

times 510-($-$$) db 0 ;fill the program with empty bytes
dw 0AA55h
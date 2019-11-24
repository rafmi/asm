section .bss
buf: resb 4096

section .text
global _start
; r8      keeps file descriptor of open file
; edi     keeps the value in current iteration
; ecx     keeps sequence of previous 5 values in one register properly encoded
; esi     temporary value, used as a mask
; r11     least bit is 1 if value from (68020, 2**31) occured,
;         second least bit is 1 if sequence 6, 8, 0, 2, 0 occured
; r9d     keeps sum of values mod 2**32
; r10     iterator of buffer loop
; rax     size of read segment

_start:
pop rax
; assert argc == 2
cmp rax, 2
jne fail

; pop program name
pop rdi
; pop filename to rdi
pop rdi

; open file to readonly
mov rax, 2
mov rsi, 0 ; for read only

syscall
; exit with 1 if error during open file
cmp rax, 0
jl fail
; r8 should not be modified from now on
mov r8, rax

; ecx can be used only as list of previous numbers
; r11 as value remembering two conditions (previously described)
; r9d keeps the sum
; they should not be used for anything else
mov ecx, 0
mov r11, 0
mov r9d, 0

read_chunk:
    ; read 4096 bytes to memory
    mov rax, 0
    mov rdi, r8
    mov rsi, buf
    mov rdx, 4096

    ; preserve values before syscall
    push rcx
    push r11
    push r9
    push rsi

    syscall

    ; restore values after syscall
    pop rsi
    pop r9
    pop r11
    pop rcx

    cmp rax, 0
    ; EOF, stop iteration
    je end
    ; error when read, exit with 1
    jl fail

;r10 used only as iterator from now on
mov r10, 0
loopstart:

    ; read value from memory
    mov edi, [buf + r10]
    ; big endian -> little endian
    bswap edi

    add r9d, edi

    cmp edi, 68020
    je fail

    jbe range_check_done
    ; compare with 2**31
    cmp edi, 2147483648
    jae range_check_done

    ; value from requested range occured
    or r11, 1

    range_check_done:

    ; if value does not fit in 4 bits, we replace it with 15 (b1111)
    cmp edi, 0
    jl seq_val_wrong
    cmp edi, 15
    jg seq_val_wrong

    seq_val_ok:
    ; esi is mask used to zero first 12 bits and leave last 20 bits
    mov esi, -1
    shr esi, 12 

    ; move list 4 bits to the left and clean first 12 bits
    shl ecx, 4
    and ecx, esi
    or ecx, edi

    ; 426016 represents sequence 6,8,0,2,0 encoded in one registers
    ; (each value fits in 4 bits, we just store them one after another)
    cmp ecx, 426016
    jne seq_not_found
    seq_found:
    or r11, 2
    seq_not_found:

    add r10, 4
    cmp r10, rax
    jl loopstart ; end of buffor
jmp read_chunk

; return successfully with 0 exit code
; check if r9d is equal 68020
; and if flags are equal to 3
; if not jump to fail
end:
    cmp r9d, 68020
    jne fail

    cmp r11, 3
    jne fail

    mov rax, 60
    mov rdi, 0
    syscall
    ret

; return fail, with 1 exit code
fail:
    mov rax, 60
    mov rdi, 1
    syscall
    ret

; cut the value, so it fits to list of previous values
seq_val_wrong:
    mov edi, 15
    jmp seq_val_ok

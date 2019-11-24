global euron
extern get_value
extern put_value

section .data
align 64
; -41 means we wait for a value
spin_locks times N*N dq -41

section .text

; registers description:
;     - r8  - keeps n
;     - r9  - keeps pointer to the string command
;     - r10 - loop iterator
;
; free to use per iteration:
;     - rax/al
;     - rsi/sil
;     - rcx

euron:
; saving state of the stack to restore it when leaving the function
push rbp
mov rbp, rsp
; saving arguments for later use
; n
mov r8, rdi
; pointer to the command string
mov r9, rsi

; loop until '\0'
mov r10, -1
loop:
    inc r10
    ; read next command
    mov dil, [r9 + r10]
    ; +
    cmp dil, 43
    je plus
    ; *
    cmp dil, 42
    je star
    ; -
    cmp dil, 45
    je minus
    ; n
    cmp dil, 110
    je n
    ; B
    cmp dil, 66
    je B
    ; C
    cmp dil, 67
    je C
    ; D
    cmp dil, 68
    je D
    ; E
    cmp dil, 69
    je E
    ; G
    cmp dil, 71
    je G
    ; P
    cmp dil, 80
    je P
    ; S
    cmp dil, 83
    je S     
    ; 0-9
    cmp dil, 48
    jl nodigit
    cmp dil, 58
    jg nodigit
    jmp digit
    nodigit:
    ; '\0'
    cmp dil, 0
    jmp endprog

; Commands:
plus:
    pop rsi
    pop rax
    add rax, rsi
    push rax
    jmp loop

star:
    pop rsi
    pop rax
    imul rax, rsi
    push rax
    jmp loop

minus:
    pop rsi
    neg rsi
    push rsi
    jmp loop

n:
    push r8
    jmp loop

endprog:
    ; get return value from stack
    pop rax
    ; fix the stack
    mov rsp, rbp
    pop rbp
    ret

digit:
    xor rax, rax
    mov al, dil
    sub al, 48
    push rax
    jmp loop

B:
    pop rax
    pop rsi
    cmp rsi, 0
    push rsi
    je loop
    add r10, rax
    jmp loop

C:
    pop rax
    jmp loop

D:
    pop rax
    push rax
    push rax
    jmp loop

E:
    pop rax
    pop rsi
    push rax
    push rsi
    jmp loop

G:
    mov rdi, r8
    push r8
    push r9
    push r10

    ; align the stack pointer to n*16
    mov rsi, 15
    and rsi, rsp
    cmp rsi, 0
    je nofix

    fix:
    push rsi
    call get_value
    pop rsi
    jmp afterfix

    nofix:
    call get_value
    afterfix:

    pop r10
    pop r9
    pop r8
    push rax
    jmp loop

P:
    mov rdi, r8
    pop rsi
    push r8
    push r9
    push r10

    ; align the stack pointer to n*16
    mov rax, 15
    and rax, rsp
    cmp rax, 0
    je nofixp

    fixp:
    push rax
    call put_value
    pop rax
    jmp afterfixp

    nofixp:
    call put_value
    afterfixp:

    pop r10
    pop r9
    pop r8
    jmp loop

S:
    ; find a partner
    pop rax
    
    ; calculate the place in the memory
    ; to leave value for the partner
    ; in rcx
    mov rcx, rax
    imul rcx, N
    add rcx, r8
    imul rcx, 8
    add rcx, spin_locks

    ; leave the value for the partner
    pop r11
    mov [rcx], r11

    ; calculate the place in the memory
    ; where the partner left value for us
    ; in rcx
    mov rcx, r8
    imul rcx, N
    add rcx, rax
    imul rcx, 8
    add rcx, spin_locks
    
    ; wait until the partner leaves the value
    mov rax, -41
    spin:
    xchg rax, [rcx]
    cmp rax, -41
    je spin

    ; update the stack with the value from the partner
    push rax

    jmp loop

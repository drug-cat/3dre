; ============================================================
; src/core/log.asm
; Simple debug output via OutputDebugStringA
; View with DbgView, Visual Studio, or DebugView++
; ============================================================
BITS 64
default rel

section .data
str_prefix:        db "[3dre] ", 0
str_error_prefix:  db "[3dre][ERROR] ", 0
str_nl:            db 13, 10, 0

section .text
global log_info
global log_error

extern OutputDebugStringA

; log_info(const char* msg)    ; rcx = msg
log_info:
    push rbx
    sub  rsp, 0x20
    mov  rbx, rcx
    lea  rcx, [str_prefix]
    call OutputDebugStringA
    mov  rcx, rbx
    call OutputDebugStringA
    lea  rcx, [str_nl]
    call OutputDebugStringA
    add  rsp, 0x20
    pop  rbx
    ret

; log_error(const char* msg)
log_error:
    push rbx
    sub  rsp, 0x20
    mov  rbx, rcx
    lea  rcx, [str_error_prefix]
    call OutputDebugStringA
    mov  rcx, rbx
    call OutputDebugStringA
    lea  rcx, [str_nl]
    call OutputDebugStringA
    add  rsp, 0x20
    pop  rbx
    ret
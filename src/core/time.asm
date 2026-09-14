; ============================================================
; src/core/time.asm
; High-resolution timing via QueryPerformanceCounter
; ============================================================
BITS 64
default rel

extern QueryPerformanceCounter
extern QueryPerformanceFrequency

section .data
align 8
qpc_freq:       dq 0
qpc_last:       dq 0
one_d:          dq 1.0

section .bss
align 4
inv_freq_f:     resd 1

section .text
global time_init
global time_dt

; ============================================================
; time_init() — call once at startup, before any time_dt call
; ============================================================
time_init:
    push rbx
    sub  rsp, 0x20

    ; QueryPerformanceFrequency(&qpc_freq)
    lea  rcx, [qpc_freq]
    call QueryPerformanceFrequency

    ; Seed qpc_last with the current counter
    lea  rcx, [qpc_last]
    call QueryPerformanceCounter

    ; inv_freq_f = 1.0 / freq  (as f32)
    mov  rax, [qpc_freq]
    cvtsi2sd xmm0, rax
    movsd xmm1, [one_d]
    divsd xmm1, xmm0
    cvtsd2ss xmm1, xmm1
    movss [inv_freq_f], xmm1

    add  rsp, 0x20
    pop  rbx
    ret

; ============================================================
; time_dt() → xmm0 = seconds since previous call
;   Clamped to at least one tick and at most 0.1s.
; ============================================================
time_dt:
    push rbx
    sub  rsp, 0x20

    ; QueryPerformanceCounter(&now at [rsp+0x10])
    lea  rcx, [rsp+0x10]
    call QueryPerformanceCounter

    ; delta = now - last
    mov  rax, [rsp+0x10]
    mov  rcx, [qpc_last]
    sub  rax, rcx

    ; save current as new last
    mov  rcx, [rsp+0x10]
    mov  [qpc_last], rcx

    ; clamp: at least 1 tick
    cmp  rax, 0
    jg   .ok_min
    mov  rax, 1
.ok_min:

    ; dt = delta / freq
    cvtsi2ss xmm0, rax
    mulss xmm0, [inv_freq_f]

    ; clamp to 0.1s max
    mov  eax, 0x3DCCCCCD           ; 0.1f
    movd xmm1, eax
    minss xmm0, xmm1

    add  rsp, 0x20
    pop  rbx
    ret
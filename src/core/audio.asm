; ============================================================
; src/core/audio.asm
; Simple sound effects via WinMM PlaySound + in-memory WAV
; ============================================================
BITS 64
default rel

extern PlaySoundA
extern LocalAlloc
extern LocalFree

section .data
align 16
wav_sample_rate:  dd 44100
wav_duration_ms:  dd 120
wav_freq:         dd 800.0
wav_amplitude:    dd 10000.0
two_pi:           dd 6.283185307179586
f_1_0:            dd 1.0

section .bss
align 8
audio_spawn_wav:  resq 1
audio_spawn_size: resd 1

section .text
global audio_init
global audio_play_spawn
global audio_shutdown

; ============================================================
; audio_init() → eax = 1/0
;   Generates a spawn "pop" WAV entirely in memory.
; ============================================================
audio_init:
    push rbx
    push rsi
    push rdi
    push r12
    sub  rsp, 0x20

    ; samples = rate * ms / 1000
    mov  eax, [wav_sample_rate]
    imul eax, [wav_duration_ms]
    mov  ecx, 1000
    xor  edx, edx
    div  ecx
    mov  ebx, eax                  ; sample count

    ; total size = 44 + samples * 2
    lea  edi, [rbx + rbx]
    add  edi, 44

    xor  ecx, ecx
    mov  edx, edi
    call LocalAlloc
    test rax, rax
    jz   .fail
    mov  rsi, rax
    mov  [audio_spawn_wav], rax
    mov  [audio_spawn_size], edi

    ; ---- RIFF header ----
    mov  dword [rsi+0], 0x46464952      ; "RIFF"
    mov  eax, edi
    sub  eax, 8
    mov  [rsi+4], eax
    mov  dword [rsi+8], 0x45564157      ; "WAVE"

    ; ---- fmt chunk ----
    mov  dword [rsi+12], 0x20746D66     ; "fmt "
    mov  dword [rsi+16], 16
    mov  word  [rsi+20], 1              ; PCM
    mov  word  [rsi+22], 1              ; mono
    mov  eax, [wav_sample_rate]
    mov  [rsi+24], eax
    shl  eax, 1                         ; byte_rate
    mov  [rsi+28], eax
    mov  word  [rsi+32], 2
    mov  word  [rsi+34], 16

    ; ---- data chunk ----
    mov  dword [rsi+36], 0x61746164     ; "data"
    mov  eax, edi
    sub  eax, 44
    mov  [rsi+40], eax

    ; ---- generate samples ----
    lea  rdi, [rsi + 44]
    xor  r12d, r12d

.sample_loop:
    cmp  r12d, ebx
    jae  .samples_done

    ; angle = 2*pi * freq * i / rate
    pxor xmm0, xmm0
    cvtsi2ss xmm0, r12d
    movss xmm1, [wav_freq]
    mulss xmm0, xmm1
    mov  eax, [wav_sample_rate]
    pxor xmm2, xmm2
    cvtsi2ss xmm2, eax
    divss xmm0, xmm2
    mulss xmm0, [two_pi]
    movss [rsp+0x00], xmm0

    fld  dword [rsp+0x00]
    fsin
    fstp dword [rsp+0x04]

    ; envelope = (1 - i/N)²
    pxor xmm0, xmm0
    cvtsi2ss xmm0, r12d
    pxor xmm1, xmm1
    cvtsi2ss xmm1, ebx
    divss xmm0, xmm1
    movss xmm1, [f_1_0]
    subss xmm1, xmm0
    mulss xmm1, xmm1

    movss xmm0, [rsp+0x04]
    mulss xmm0, xmm1
    mulss xmm0, [wav_amplitude]

    cvttss2si eax, xmm0
    cmp  eax, 32767
    jle  .no_hi
    mov  eax, 32767
.no_hi:
    cmp  eax, -32768
    jge  .no_lo
    mov  eax, -32768
.no_lo:
    mov  [rdi], ax
    add  rdi, 2
    inc  r12d
    jmp  .sample_loop

.samples_done:
    mov  eax, 1
    add  rsp, 0x20
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbx
    ret
.fail:
    xor  eax, eax
    add  rsp, 0x20
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
; audio_play_spawn()
; ============================================================
audio_play_spawn:
    sub  rsp, 0x28
    mov  rcx, [audio_spawn_wav]
    test rcx, rcx
    jz   .done
    xor  edx, edx
    mov  r8d, 0x0005              ; SND_MEMORY | SND_ASYNC
    call PlaySoundA
.done:
    add  rsp, 0x28
    ret

; ============================================================
; audio_shutdown()
; ============================================================
audio_shutdown:
    sub  rsp, 0x28

    ; stop any playing sound
    xor  ecx, ecx
    xor  edx, edx
    xor  r8d, r8d
    call PlaySoundA

    mov  rcx, [audio_spawn_wav]
    test rcx, rcx
    jz   .done
    call LocalFree
    mov  qword [audio_spawn_wav], 0

.done:
    add  rsp, 0x28
    ret
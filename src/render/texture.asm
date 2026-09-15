; ============================================================
; src/render/texture.asm
; GL texture wrapper + procedural checkerboard + PNG/JPG loading
; ============================================================
BITS 64
default rel

%include "gl.inc"
%include "texture.inc"

; ---- GL 1.1 direct from opengl32.dll ----
extern glGenTextures
extern glBindTexture
extern glDeleteTextures
extern glTexImage2D
extern glTexParameteri

; ---- Function pointer from gl_loader.asm ----
extern glActiveTexture

; ---- Image loading (WIC wrapper) ----
extern image_load

; ---- Win32 heap ----
extern LocalAlloc
extern LocalFree

section .text
global texture_create_checkerboard
global texture_create_from_file
global texture_bind
global texture_destroy

; ============================================================
; texture_create_checkerboard(Texture* t, u32 cell_px, u32 squares_per_side)
;   rcx = t
;   edx = cell size in pixels
;   r8d = squares per side
; ============================================================
texture_create_checkerboard:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 0x50

    mov  rbx, rcx                  ; Texture*
    mov  r12d, edx                 ; cell size
    mov  r13d, r8d                 ; squares per side

    ; dimension = cell * squares
    mov  r14d, r12d
    imul r14d, r13d

    mov  [rbx + TEX_WIDTH],  r14d
    mov  [rbx + TEX_HEIGHT], r14d
    mov  dword [rbx + TEX_FORMAT], GL_RGB

    ; ---- alloc pixel buffer (dim*dim*3) ----
    mov  eax, r14d
    imul eax, r14d
    lea  edx, [rax + rax*2]
    xor  ecx, ecx                  ; LMEM_FIXED
    call LocalAlloc
    test rax, rax
    jz   .fail
    mov  r15, rax

    ; ---- fill pixels ----
    xor  edi, edi                  ; y
.y_loop:
    cmp  edi, r14d
    jae  .y_done

    xor  esi, esi                  ; x
.x_loop:
    cmp  esi, r14d
    jae  .x_done

    mov  eax, esi
    xor  edx, edx
    div  r12d
    mov  r10d, eax

    mov  eax, edi
    xor  edx, edx
    div  r12d
    add  r10d, eax
    and  r10d, 1

    mov  al, 128
    test r10d, r10d
    jnz  .use_grey
    mov  al, 255
.use_grey:

    mov  edx, edi
    imul edx, r14d
    add  edx, esi
    lea  edx, [rdx + rdx*2]

    mov  [r15 + rdx + 0], al
    mov  [r15 + rdx + 1], al
    mov  [r15 + rdx + 2], al

    inc  esi
    jmp  .x_loop
.x_done:
    inc  edi
    jmp  .y_loop
.y_done:

    ; ---- glGenTextures ----
    mov  ecx, 1
    lea  rdx, [rbx + TEX_ID]
    call glGenTextures

    mov  ecx, GL_TEXTURE_2D
    mov  edx, [rbx + TEX_ID]
    call glBindTexture

    ; ---- sampler params ----
    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_WRAP_S
    mov  r8d, GL_REPEAT
    call glTexParameteri

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_WRAP_T
    mov  r8d, GL_REPEAT
    call glTexParameteri

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_MIN_FILTER
    mov  r8d, GL_NEAREST
    call glTexParameteri

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_MAG_FILTER
    mov  r8d, GL_NEAREST
    call glTexParameteri

    ; ---- glTexImage2D (5 stack args: h, border, fmt, type, pixels) ----
    mov  ecx, GL_TEXTURE_2D
    xor  edx, edx
    mov  r8d, GL_RGB
    mov  r9d, r14d
    mov  [rsp+0x20], r14d
    mov  qword [rsp+0x28], 0
    mov  dword [rsp+0x30], GL_RGB
    mov  dword [rsp+0x38], GL_UNSIGNED_BYTE
    mov  [rsp+0x40], r15
    call glTexImage2D

    ; ---- free temp ----
    mov  rcx, r15
    call LocalFree

    mov  eax, 1
    jmp  .done

.fail:
    xor  eax, eax

.done:
    add  rsp, 0x50
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
; texture_create_from_file(Texture* t, const char* path) → eax = 1/0
;   rcx = t
;   rdx = ANSI path (absolute or relative to CWD)
; ============================================================
texture_create_from_file:
    push rbx
    push rsi
    push rdi
    sub  rsp, 0x50

    mov  rbx, rcx                  ; Texture*
    mov  rdi, rdx                  ; path

    ; zero struct
    pxor xmm0, xmm0
    movdqu [rbx],    xmm0

    ; ---- image_load(path, &w, &h) ----
    mov  rcx, rdi
    lea  rdx, [rsp+0x10]           ; &w
    lea  r8,  [rsp+0x14]           ; &h
    call image_load
    test rax, rax
    jz   .fail
    mov  rsi, rax                  ; pixel buffer (BGRA8)

    ; ---- metadata ----
    mov  eax, [rsp+0x10]
    mov  [rbx + TEX_WIDTH], eax
    mov  eax, [rsp+0x14]
    mov  [rbx + TEX_HEIGHT], eax
    mov  dword [rbx + TEX_FORMAT], GL_RGBA

    ; ---- glGenTextures ----
    mov  ecx, 1
    lea  rdx, [rbx + TEX_ID]
    call glGenTextures

    mov  ecx, GL_TEXTURE_2D
    mov  edx, [rbx + TEX_ID]
    call glBindTexture

    ; ---- sampler params ----
    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_WRAP_S
    mov  r8d, GL_REPEAT
    call glTexParameteri

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_WRAP_T
    mov  r8d, GL_REPEAT
    call glTexParameteri

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_MIN_FILTER
    mov  r8d, GL_LINEAR
    call glTexParameteri

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_MAG_FILTER
    mov  r8d, GL_LINEAR
    call glTexParameteri

    ; ---- glTexImage2D(target, 0, GL_RGBA, w, h, 0, GL_BGRA, GL_UNSIGNED_BYTE, pixels) ----
    ; stack args: height, border, format, type, pixels
    mov  ecx, GL_TEXTURE_2D
    xor  edx, edx
    mov  r8d, GL_RGBA
    mov  r9d, [rbx + TEX_WIDTH]
    mov  eax, [rbx + TEX_HEIGHT]
    mov  [rsp+0x20], eax
    mov  qword [rsp+0x28], 0
    mov  dword [rsp+0x30], GL_BGRA
    mov  dword [rsp+0x38], GL_UNSIGNED_BYTE
    mov  [rsp+0x40], rsi
    call glTexImage2D

    ; ---- free pixel buffer ----
    mov  rcx, rsi
    call LocalFree

    mov  eax, 1
    add  rsp, 0x50
    pop  rdi
    pop  rsi
    pop  rbx
    ret

.fail:
    xor  eax, eax
    add  rsp, 0x50
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
; texture_bind(Texture* t, u32 unit)
;   rcx = t
;   edx = GL texture unit (GL_TEXTURE0, GL_TEXTURE1, ...)
; ============================================================
texture_bind:
    push rbx
    sub  rsp, 0x20
    mov  rbx, rcx

    ; glActiveTexture(unit) — function pointer!
    mov  ecx, edx
    call qword [glActiveTexture]

    ; glBindTexture(GL_TEXTURE_2D, t->id)
    mov  ecx, GL_TEXTURE_2D
    mov  edx, [rbx + TEX_ID]
    call glBindTexture

    add  rsp, 0x20
    pop  rbx
    ret

; ============================================================
; texture_destroy(Texture* t)
; ============================================================
texture_destroy:
    push rbx
    sub  rsp, 0x20
    mov  rbx, rcx

    cmp  dword [rbx + TEX_ID], 0
    je   .done

    mov  ecx, 1
    lea  rdx, [rbx + TEX_ID]
    call glDeleteTextures

    mov  dword [rbx + TEX_ID], 0

.done:
    add  rsp, 0x20
    pop  rbx
    ret
; ============================================================
; src/render/framebuffer.asm
; Depth-only framebuffer for shadow mapping
;
; IMPORTANT: glGenFramebuffers etc. are function POINTERS loaded
; by gl_loader.asm. Every call must go through [..]:
;     call qword [glGenFramebuffers]
; NOT:
;     call glGenFramebuffers      ; ← that jumps to the storage slot
; ============================================================
BITS 64
default rel

%include "gl.inc"
%include "framebuffer.inc"

; ---- function pointers from gl_loader ----
extern glGenFramebuffers
extern glBindFramebuffer
extern glFramebufferTexture2D
extern glCheckFramebufferStatus
extern glDeleteFramebuffers

; ---- GL 1.1 direct from opengl32.dll ----
extern glGenTextures
extern glBindTexture
extern glTexImage2D
extern glTexParameteri
extern glTexParameterfv
extern glDrawBuffer
extern glReadBuffer
extern glDeleteTextures

section .data
align 16
border_color:   dd 1.0, 1.0, 1.0, 1.0

section .text
global framebuffer_create_shadow
global framebuffer_bind
global framebuffer_unbind
global framebuffer_destroy

; ============================================================
; framebuffer_create_shadow(FrameBuffer* fb, u32 w, u32 h) → eax = 1/0
; ============================================================
framebuffer_create_shadow:
    push rbx
    sub  rsp, 0x60
    mov  rbx, rcx

    mov  [rbx + FB_WIDTH], edx
    mov  [rbx + FB_HEIGHT], r8d

    ; ---- depth texture ----
    mov  ecx, 1
    lea  rdx, [rbx + FB_DEPTH_TEX]
    call glGenTextures

    mov  ecx, GL_TEXTURE_2D
    mov  edx, [rbx + FB_DEPTH_TEX]
    call glBindTexture

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_MIN_FILTER
    mov  r8d, GL_NEAREST
    call glTexParameteri

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_MAG_FILTER
    mov  r8d, GL_NEAREST
    call glTexParameteri

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_WRAP_S
    mov  r8d, GL_CLAMP_TO_BORDER
    call glTexParameteri

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_WRAP_T
    mov  r8d, GL_CLAMP_TO_BORDER
    call glTexParameteri

    mov  ecx, GL_TEXTURE_2D
    mov  edx, GL_TEXTURE_BORDER_COLOR
    lea  r8,  [border_color]
    call glTexParameterfv

    ; glTexImage2D(target, 0, DEPTH24, w, h, 0, DEPTH, FLOAT, NULL)
    mov  ecx, GL_TEXTURE_2D
    xor  edx, edx
    mov  r8d, GL_DEPTH_COMPONENT24
    mov  r9d, [rbx + FB_WIDTH]
    mov  eax, [rbx + FB_HEIGHT]
    mov  [rsp+0x20], eax
    mov  qword [rsp+0x28], 0
    mov  dword [rsp+0x30], GL_DEPTH_COMPONENT
    mov  dword [rsp+0x38], GL_FLOAT
    mov  qword [rsp+0x40], 0
    call glTexImage2D

    ; ---- FBO ----
    mov  ecx, 1
    lea  rdx, [rbx + FB_FBO]
    call qword [glGenFramebuffers]            ; ← FIX

    mov  ecx, GL_FRAMEBUFFER
    mov  edx, [rbx + FB_FBO]
    call qword [glBindFramebuffer]            ; ← FIX

    ; glFramebufferTexture2D(GL_FRAMEBUFFER, DEPTH_ATTACHMENT,
    ;                        GL_TEXTURE_2D, tex, 0)
    mov  ecx, GL_FRAMEBUFFER
    mov  edx, GL_DEPTH_ATTACHMENT
    mov  r8d, GL_TEXTURE_2D
    mov  r9d, [rbx + FB_DEPTH_TEX]
    mov  qword [rsp+0x20], 0
    call qword [glFramebufferTexture2D]       ; ← FIX

    mov  ecx, GL_NONE
    call glDrawBuffer

    mov  ecx, GL_NONE
    call glReadBuffer

    mov  ecx, GL_FRAMEBUFFER
    call qword [glCheckFramebufferStatus]     ; ← FIX
    cmp  eax, GL_FRAMEBUFFER_COMPLETE
    jne  .fail

    mov  ecx, GL_FRAMEBUFFER
    xor  edx, edx
    call qword [glBindFramebuffer]            ; ← FIX

    mov  eax, 1
    add  rsp, 0x60
    pop  rbx
    ret
.fail:
    xor  eax, eax
    add  rsp, 0x60
    pop  rbx
    ret

; ============================================================
framebuffer_bind:                             ; rcx = fb
    mov  edx, [rcx + FB_FBO]
    mov  ecx, GL_FRAMEBUFFER
    jmp  qword [glBindFramebuffer]            ; ← FIX

; ============================================================
framebuffer_unbind:
    sub  rsp, 0x28
    mov  ecx, GL_FRAMEBUFFER
    xor  edx, edx
    call qword [glBindFramebuffer]            ; ← FIX
    add  rsp, 0x28
    ret

; ============================================================
framebuffer_destroy:                          ; rcx = fb
    push rbx
    sub  rsp, 0x20
    mov  rbx, rcx

    cmp  dword [rbx + FB_FBO], 0
    je   .no_fbo
    mov  ecx, 1
    lea  rdx, [rbx + FB_FBO]
    call qword [glDeleteFramebuffers]         ; ← FIX
    mov  dword [rbx + FB_FBO], 0
.no_fbo:
    cmp  dword [rbx + FB_DEPTH_TEX], 0
    je   .done
    mov  ecx, 1
    lea  rdx, [rbx + FB_DEPTH_TEX]
    call glDeleteTextures
    mov  dword [rbx + FB_DEPTH_TEX], 0
.done:
    add  rsp, 0x20
    pop  rbx
    ret
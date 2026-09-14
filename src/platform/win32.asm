; ============================================================
; src/platform/win32.asm
; Window creation + OpenGL 3.3 Core context
; ============================================================
BITS 64
default rel

%include "win32.inc"

; ---- PFD flags ----
%define PFD_DOUBLEBUFFER      0x00000001
%define PFD_DRAW_TO_WINDOW    0x00000004
%define PFD_SUPPORT_OPENGL    0x00000020
%define PFD_TYPE_RGBA         0

; ---- WGL ARB constants ----
%define WGL_CONTEXT_MAJOR_VERSION_ARB     0x2091
%define WGL_CONTEXT_MINOR_VERSION_ARB     0x2092
%define WGL_CONTEXT_PROFILE_MASK_ARB      0x9126
%define WGL_CONTEXT_CORE_PROFILE_BIT_ARB  0x00000001

section .data
align 16
class_name db "3dreWindowClass",0
str_wglCreateContextAttribsARB db "wglCreateContextAttribsARB",0

; ---- PIXELFORMATDESCRIPTOR (exactly 40 bytes) ----
align 16
pfd:
    dw 40                                                         ; nSize
    dw 1                                                          ; nVersion
    dd PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER ; dwFlags
    db PFD_TYPE_RGBA                                              ; iPixelType
    db 32                                                         ; cColorBits
    db 0, 0, 0, 0, 0, 0, 0, 0                                     ; red/green/blue/alpha bits+shifts (8)
    db 0, 0, 0, 0, 0                                              ; accum bits (5)
    db 24                                                         ; cDepthBits
    db 8                                                          ; cStencilBits
    db 0                                                          ; cAuxBuffers
    db 0                                                          ; iLayerType
    db 0                                                          ; bReserved
    dd 0                                                          ; dwLayerMask
    dd 0                                                          ; dwVisibleMask
    dd 0                                                          ; dwDamageMask

align 4
attribs_33_core:
    dd WGL_CONTEXT_MAJOR_VERSION_ARB, 3
    dd WGL_CONTEXT_MINOR_VERSION_ARB, 3
    dd WGL_CONTEXT_PROFILE_MASK_ARB,  WGL_CONTEXT_CORE_PROFILE_BIT_ARB
    dd 0, 0

section .bss
align 8
hDC          resq 1
hLegacyRC    resq 1
hRC          resq 1
hwnd_global  resq 1
wglCreateCtxAttribs resq 1

section .text
global win32_register_class
global win32_create_window
global win32_create_gl_context
global win32_destroy_gl_context
global win32_swap_buffers

extern RegisterClassExA
extern CreateWindowExA
extern GetDC
extern ReleaseDC
extern ChoosePixelFormat
extern SetPixelFormat
extern wglCreateContext
extern wglMakeCurrent
extern wglDeleteContext
extern wglGetProcAddress
extern SwapBuffers

; ============================================================
; win32_register_class(hInstance, WndProc, className)
;   rcx = hInstance
;   rdx = WndProc pointer
;   r8  = class name string (0 = use default)
; Returns: eax = 1 / 0
; ============================================================
win32_register_class:
    push rbx
    sub  rsp, 0x60

    mov  rbx, rcx

    ; WNDCLASSEXA layout (x64):
    ;   0  cbSize        (u32)
    ;   4  style         (u32)
    ;   8  lpfnWndProc   (ptr)
    ;  16  cbClsExtra    (i32)
    ;  20  cbWndExtra    (i32)
    ;  24  hInstance     (ptr)
    ;  32  hIcon         (ptr)
    ;  40  hCursor       (ptr)
    ;  48  hbrBackground (ptr)
    ;  56  lpszMenuName  (ptr)
    ;  64  lpszClassName (ptr)
    ;  72  hIconSm       (ptr)
    mov  dword [rsp+0],  80
    mov  dword [rsp+4],  CS_HREDRAW | CS_VREDRAW | CS_OWNDC
    mov  [rsp+8],  rdx
    mov  dword [rsp+16], 0
    mov  dword [rsp+20], 0
    mov  [rsp+24], rbx
    xor  rax, rax
    mov  [rsp+32], rax
    mov  [rsp+40], rax
    mov  [rsp+48], rax
    mov  [rsp+56], rax
    test r8, r8
    jnz  .has_name
    lea  rax, [class_name]
    jmp  .set_name
.has_name:
    mov  rax, r8
.set_name:
    mov  [rsp+64], rax
    mov  qword [rsp+72], 0

    mov  rcx, rsp
    call RegisterClassExA
    test rax, rax
    jz   .fail
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
; win32_create_window(hInstance, title, width, height)
;   rcx = hInstance
;   rdx = title string
;   r8  = width  (int)
;   r9  = height (int)
; Returns: rax = hwnd (0 on failure)
; ============================================================
win32_create_window:
    push rbx
    push rsi
    push rdi
    push r12
    sub  rsp, 0x88

    mov  rbx, rcx                  ; hInstance
    mov  rsi, rdx                  ; title
    mov  rdi, r8                   ; width
    mov  r12, r9                   ; height

    ; CreateWindowExA(dwExStyle, lpClassName, lpWindowName, dwStyle,
    ;                 X, Y, nWidth, nHeight,
    ;                 hWndParent, hMenu, hInstance, lpParam)
    xor  ecx, ecx                  ; dwExStyle
    lea  rdx, [class_name]         ; lpClassName
    mov  r8,  rsi                  ; lpWindowName
    mov  r9d, WS_OVERLAPPEDWINDOW  ; dwStyle
    mov  eax, CW_USEDEFAULT
    mov  [rsp+0x20], rax                   ; X
    mov  [rsp+0x28], rax                   ; Y
    mov  [rsp+0x30], rdi                   ; nWidth
    mov  [rsp+0x38], r12                   ; nHeight
    mov  qword [rsp+0x40], 0               ; hWndParent
    mov  qword [rsp+0x48], 0               ; hMenu
    mov  [rsp+0x50], rbx                   ; hInstance
    mov  qword [rsp+0x58], 0               ; lpParam

    call CreateWindowExA
    add  rsp, 0x88
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
; win32_create_gl_context(hwnd)
;   rcx = hwnd
; Returns: eax = 1 / 0
; ============================================================
win32_create_gl_context:
    push rbx
    push rsi
    push rdi
    sub  rsp, 0x20

    mov  rbx, rcx
    mov  [hwnd_global], rcx

    ; GetDC
    mov  rcx, rbx
    call GetDC
    test rax, rax
    jz   .fail
    mov  [hDC], rax
    mov  rsi, rax                  ; rsi = hDC

    ; ChoosePixelFormat
    mov  rcx, rsi
    lea  rdx, [pfd]
    call ChoosePixelFormat
    test eax, eax
    jz   .fail_release
    mov  edi, eax                  ; edi = pixel format index

    ; SetPixelFormat
    mov  rcx, rsi
    mov  edx, edi
    lea  r8,  [pfd]
    call SetPixelFormat
    test eax, eax
    jz   .fail_release

    ; Legacy context (needed to get wglGetProcAddress on some drivers)
    mov  rcx, rsi
    call wglCreateContext
    test rax, rax
    jz   .fail_release
    mov  [hLegacyRC], rax

    mov  rcx, rsi
    mov  rdx, rax
    call wglMakeCurrent
    test eax, eax
    jz   .fail_legacy

    ; Get wglCreateContextAttribsARB
    lea  rcx, [str_wglCreateContextAttribsARB]
    call wglGetProcAddress
    test rax, rax
    jz   .fail_legacy
    mov  [wglCreateCtxAttribs], rax

    ; Create 3.3 core context
    mov  rcx, rsi
    xor  edx, edx
    lea  r8,  [attribs_33_core]
    call qword [wglCreateCtxAttribs]
    test rax, rax
    jz   .fail_legacy
    mov  [hRC], rax

    ; Make it current
    mov  rcx, rsi
    mov  rdx, rax
    call wglMakeCurrent
    test eax, eax
    jz   .fail_new

    ; Delete legacy context
    mov  rcx, [hLegacyRC]
    call wglDeleteContext
    mov  qword [hLegacyRC], 0

    mov  eax, 1
    add  rsp, 0x20
    pop  rdi
    pop  rsi
    pop  rbx
    ret

.fail_new:
    mov  rcx, [hRC]
    call wglDeleteContext
    mov  qword [hRC], 0
.fail_legacy:
    mov  rcx, [hLegacyRC]
    test rcx, rcx
    jz   .skip_del_legacy
    call wglDeleteContext
    mov  qword [hLegacyRC], 0
.skip_del_legacy:
.fail_release:
    mov  rcx, rbx                  ; hwnd
    mov  rdx, [hDC]
    call ReleaseDC
    mov  qword [hDC], 0
.fail:
    xor  eax, eax
    add  rsp, 0x20
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
; win32_destroy_gl_context()
; ============================================================
win32_destroy_gl_context:
    sub  rsp, 0x28

    ; Release DC
    mov  rax, [hDC]
    test rax, rax
    jz   .no_dc
    mov  rdx, rax                  ; hdc
    mov  rcx, [hwnd_global]        ; hwnd
    test rcx, rcx
    jz   .no_dc
    call ReleaseDC
    mov  qword [hDC], 0
.no_dc:
    ; Delete GL context
    mov  rcx, [hRC]
    test rcx, rcx
    jz   .no_rc
    call wglDeleteContext
    mov  qword [hRC], 0
.no_rc:
    add  rsp, 0x28
    ret

; ============================================================
; win32_swap_buffers()
; ============================================================
win32_swap_buffers:
    sub  rsp, 0x28
    mov  rcx, [hDC]
    test rcx, rcx
    jz   .skip
    call SwapBuffers
.skip:
    add  rsp, 0x28
    ret
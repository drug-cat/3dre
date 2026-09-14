; test_gl.asm
BITS 64
default rel

%define WIDTH 640
%define HEIGHT 480

extern GetModuleHandleA
extern RegisterClassExA
extern AdjustWindowRect
extern CreateWindowExA
extern ShowWindow
extern UpdateWindow
extern PeekMessageA
extern TranslateMessage
extern DispatchMessageA
extern DefWindowProcA
extern PostQuitMessage
extern DestroyWindow
extern GetDC
extern ReleaseDC
extern ChoosePixelFormat
extern SetPixelFormat
extern wglCreateContext
extern wglMakeCurrent
extern wglDeleteContext
extern SwapBuffers
extern glClear
extern glClearColor

section .data
className db "TestGL",0
windowTitle db "OpenGL Test",0

pfd:
    dw 44
    dw 1
    dd 0x00000004 | 0x00000020 | 0x00000001   ; PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER
    db 0                                        ; PFD_TYPE_RGBA
    db 32                                       ; cColorBits
    db 0,0,0,0,0,0,0,0                          ; cRedBits..cAlphaShift
    db 0,0,0,0,0                                ; cAccumBits..cAccumAlphaBits
    db 0,0,0,0,0,0,0,0                          ; cAccumRedShift..cAccumAlphaShift
    db 24                                       ; cDepthBits
    db 0                                        ; cStencilBits
    db 0                                        ; cAuxBuffers
    db 0                                        ; iLayerType
    db 0                                        ; bReserved
    dd 0                                        ; dwLayerMask
    dd 0                                        ; dwVisibleMask
    dd 0                                        ; dwDamageMask

val_02 dd 0.2
val_03 dd 0.3
val_04 dd 0.4
val_1  dd 1.0

section .bss
hInstance resq 1
hwnd resq 1
hDC resq 1
hRC resq 1
wcex resb 80
rect resb 16
msg resb 48

section .text
global WinMain

WinMain:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x40

    xor ecx, ecx
    call GetModuleHandleA
    mov [hInstance], rax

    ; WNDCLASSEX
    mov dword [wcex+0], 80
    mov dword [wcex+4], 0x0002 | 0x0001 | 0x0020   ; CS_HREDRAW | CS_VREDRAW | CS_OWNDC
    lea rax, [WndProc]
    mov [wcex+8], rax
    mov dword [wcex+16], 0
    mov dword [wcex+20], 0
    mov rax, [hInstance]
    mov [wcex+24], rax
    xor rax, rax
    mov [wcex+32], rax
    mov [wcex+40], rax
    mov [wcex+48], rax
    mov [wcex+56], rax
    lea rax, [className]
    mov [wcex+64], rax
    mov qword [wcex+72], 0

    lea rcx, [wcex]
    call RegisterClassExA
    test rax, rax
    jz .exit

    ; AdjustWindowRect
    mov dword [rect+0], 0
    mov dword [rect+4], 0
    mov dword [rect+8], WIDTH
    mov dword [rect+12], HEIGHT
    lea rcx, [rect]
    mov rdx, 0x00CF0000      ; WS_OVERLAPPEDWINDOW
    xor r8d, r8d
    call AdjustWindowRect

    mov eax, dword [rect+8]
    sub eax, dword [rect+0]
    mov ebx, eax
    mov eax, dword [rect+12]
    sub eax, dword [rect+4]
    mov esi, eax

    ; CreateWindowExA
    sub rsp, 0x60
    xor ecx, ecx
    lea rdx, [className]
    lea r8, [windowTitle]
    mov r9d, 0x00CF0000
    mov r10d, 0x80000000      ; CW_USEDEFAULT
    mov [rsp+32], r10
    mov [rsp+40], r10
    movsxd r10, ebx
    mov [rsp+48], r10
    movsxd r10, esi
    mov [rsp+56], r10
    mov qword [rsp+64], 0
    mov qword [rsp+72], 0
    mov rax, [hInstance]
    mov [rsp+80], rax
    mov qword [rsp+88], 0
    call CreateWindowExA
    add rsp, 0x60
    test rax, rax
    jz .exit
    mov [hwnd], rax

    mov rcx, rax
    mov edx, 5                ; SW_SHOW
    call ShowWindow
    mov rcx, [hwnd]
    call UpdateWindow

    ; OpenGL init
    mov rcx, [hwnd]
    call GetDC
    mov [hDC], rax

    mov rcx, [hDC]
    lea rdx, [pfd]
    call ChoosePixelFormat
    mov ebx, eax

    mov rcx, [hDC]
    mov edx, ebx
    lea r8, [pfd]
    call SetPixelFormat

    mov rcx, [hDC]
    call wglCreateContext
    mov [hRC], rax

    mov rcx, [hDC]
    mov rdx, rax
    call wglMakeCurrent

    movss xmm0, [val_02]
    movss xmm1, [val_03]
    movss xmm2, [val_04]
    movss xmm3, [val_1]
    call glClearColor

.loop:
    sub rsp, 0x30
    lea rcx, [msg]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    mov dword [rsp+32], 1      ; PM_REMOVE
    call PeekMessageA
    add rsp, 0x30
    test eax, eax
    jz .render

    cmp dword [msg+8], 0x0012  ; WM_QUIT
    je .exit
    lea rcx, [msg]
    call TranslateMessage
    lea rcx, [msg]
    call DispatchMessageA
    jmp .loop

.render:
    mov ecx, 0x00004000 | 0x00000100   ; GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT
    call glClear
    mov rcx, [hDC]
    call SwapBuffers
    jmp .loop

.exit:
    mov rcx, [hRC]
    call wglDeleteContext
    mov rcx, [hwnd]
    mov rdx, [hDC]
    call ReleaseDC

    add rsp, 0x40
    pop rdi
    pop rsi
    pop rbx
    xor eax, eax
    ret

WndProc:
    sub rsp, 0x28
    cmp edx, 0x0002              ; WM_DESTROY
    je .destroy
    cmp edx, 0x0100              ; WM_KEYDOWN
    je .keydown
    add rsp, 0x28
    jmp DefWindowProcA
.destroy:
    xor ecx, ecx
    call PostQuitMessage
    add rsp, 0x28
    xor eax, eax
    ret
.keydown:
    cmp r8d, 0x1B                ; VK_ESCAPE
    jne .def
    call DestroyWindow
    add rsp, 0x28
    xor eax, eax
    ret
.def:
    add rsp, 0x28
    jmp DefWindowProcA
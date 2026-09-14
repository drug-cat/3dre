

BITS 64
default rel

%define WIDTH 640
%define HEIGHT 480
%define WIN_STYLE 0x00CF0000
%define CW_USEDEFAULT 0x80000000
%define CS_HREDRAW 0x0002
%define CS_VREDRAW 0x0001
%define CS_OWNDC 0x0020
%define SW_SHOW 5
%define PM_REMOVE 1
%define WM_DESTROY 0x0002
%define WM_KEYDOWN 0x0100
%define VK_ESCAPE 0x1B
%define VK_W 0x57
%define VK_S 0x53
%define VK_A 0x41
%define VK_D 0x44
%define VK_Q 0x51
%define VK_E 0x45
%define WM_QUIT 0x0012

GL_COLOR_BUFFER_BIT   equ 0x00004000
GL_DEPTH_BUFFER_BIT   equ 0x00000100
GL_MODELVIEW          equ 0x1700
GL_PROJECTION         equ 0x1701
GL_DEPTH_TEST         equ 0x0B71
GL_LIGHTING           equ 0x0B50
GL_LIGHT0             equ 0x4000
GL_SMOOTH             equ 0x1D01
GL_FRONT              equ 0x0404
GL_AMBIENT            equ 0x1200
GL_DIFFUSE            equ 0x1201
GL_SPECULAR           equ 0x1202
GL_POSITION           equ 0x1203
GL_SHININESS          equ 0x1601
GL_QUADS              equ 0x0007

PFD_TYPE_RGBA         equ 0
PFD_MAIN_PLANE        equ 0
PFD_DOUBLEBUFFER      equ 0x00000001
PFD_DRAW_TO_WINDOW    equ 0x00000004
PFD_SUPPORT_OPENGL    equ 0x00000020

STD_OUTPUT_HANDLE     equ -11
STD_ERROR_HANDLE      equ -12

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
extern glMatrixMode
extern glLoadIdentity
extern glFrustum
extern glViewport
extern glTranslatef
extern glRotatef
extern glEnable
extern glShadeModel
extern glLightfv
extern glMaterialfv
extern glBegin
extern glColor3f
extern glVertex3f
extern glEnd
extern WriteFile
extern GetStdHandle
extern GetLastError
extern wsprintfA

section .data
align 16
className db "OpenGLCube",0
windowTitle db "OpenGL Cube - WASD+QE, Esc exit",0


msg_init_start   db "init_opengl start",13,10,0
msg_getdc        db "GetDC ok",13,10,0
msg_choose_pf    db "ChoosePixelFormat ok",13,10,0
msg_set_pf       db "SetPixelFormat ok",13,10,0
msg_create_rc    db "wglCreateContext ok",13,10,0
msg_make_current db "wglMakeCurrent ok",13,10,0
msg_render_start db "render_frame start",13,10,0
msg_render_end   db "render_frame end",13,10,0
msg_error        db "ERROR: ",0
msg_newline      db 13,10,0
msg_error_code   db "Error code: %lu",13,10,0
msg_fail         db "Function failed",13,10,0

align 16
lightPos    dd 1.0, 1.0, 1.0, 0.0
lightAmb    dd 0.2, 0.2, 0.2, 1.0
lightDiff   dd 0.8, 0.8, 0.8, 1.0
lightSpec   dd 1.0, 1.0, 1.0, 1.0

matAmb      dd 0.2, 0.2, 0.2, 1.0
matDiff     dd 0.8, 0.8, 0.8, 1.0
matSpec     dd 1.0, 1.0, 1.0, 1.0
matShin     dd 64.0

align 16
pfd:
    dw 44                           ; nSize
    dw 1                            ; nVersion
    dd PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER
    db PFD_TYPE_RGBA                ; iPixelType
    db 32                           ; cColorBits
    db 0                            ; cRedBits
    db 0                            ; cRedShift
    db 0                            ; cGreenBits
    db 0                            ; cGreenShift
    db 0                            ; cBlueBits
    db 0                            ; cBlueShift
    db 0                            ; cAlphaBits
    db 0                            ; cAlphaShift
    db 0                            ; cAccumBits
    db 0                            ; cAccumRedBits
    db 0                            ; cAccumGreenBits
    db 0                            ; cAccumBlueBits
    db 0                            ; cAccumAlphaBits
    db 0                            ; cAccumRedShift
    db 0                            ; cAccumGreenShift
    db 0                            ; cAccumBlueShift
    db 0                            ; cAccumAlphaShift
    db 24                           ; cDepthBits
    db 0                            ; cStencilBits
    db 0                            ; cAuxBuffers
    db 0                            ; iLayerType
    db 0                            ; bReserved
    dd PFD_MAIN_PLANE               ; dwLayerMask
    dd 0                            ; dwVisibleMask
    dd 0                            ; dwDamageMask

align 16
float_one   dd 1.0
float_zero  dd 0.0
float_minus_one dd -1.0

align 16
d_left   dq -1.0
d_right  dq  1.0
d_bottom dq -1.0
d_top    dq  1.0
d_near   dq  1.5
d_far    dq  20.0

camDist     dd 8.0
camYaw      dd 0.0
camPitch    dd 0.0
camSpeed    dd 0.2
rotSpeed    dd 2.0
angleX      dd 0.0
angleY      dd 0.0
deltaX      dd 1.5
deltaY      dd 1.0

section .bss
align 16
hInstance resq 1
hwnd resq 1
hDC resq 1
hRC resq 1
wcex resb 80
rect resb 16
msg resb 48

section .text
global WinMain

log_msg:
    sub rsp, 0x28
    mov rdx, rcx
    xor eax, eax
.strlen_loop:
    cmp byte [rdx], 0
    je .strlen_done
    inc rdx
    inc eax
    jmp .strlen_loop
.strlen_done:
    mov r8d, eax          
    mov ecx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov rcx, rax
    mov rdx, [rsp+0x28+8] 
    add rsp, 0x28
    ret

show_error:
    sub rsp, 0x28
    add rsp, 0x28
    ret

WinMain:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x40

    xor ecx, ecx
    call GetModuleHandleA
    mov [hInstance], rax

    mov dword [wcex+0], 80
    mov dword [wcex+4], CS_HREDRAW | CS_VREDRAW | CS_OWNDC
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

    mov dword [rect+0], 0
    mov dword [rect+4], 0
    mov dword [rect+8], WIDTH
    mov dword [rect+12], HEIGHT
    lea rcx, [rect]
    mov rdx, WIN_STYLE
    xor r8d, r8d
    call AdjustWindowRect

    mov eax, dword [rect+8]
    sub eax, dword [rect+0]
    mov ebx, eax
    mov eax, dword [rect+12]
    sub eax, dword [rect+4]
    mov esi, eax

    sub rsp, 0x60
    xor ecx, ecx
    lea rdx, [className]
    lea r8, [windowTitle]
    mov r9d, WIN_STYLE
    mov r10d, CW_USEDEFAULT
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
    mov edx, SW_SHOW
    call ShowWindow
    mov rcx, [hwnd]
    call UpdateWindow

    call init_opengl
    test eax, eax
    jz .exit

.loop:
    sub rsp, 0x30
    lea rcx, [msg]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    mov dword [rsp+32], PM_REMOVE
    call PeekMessageA
    add rsp, 0x30
    test eax, eax
    jz .render

    cmp dword [msg+8], WM_QUIT
    je .exit
    lea rcx, [msg]
    call TranslateMessage
    lea rcx, [msg]
    call DispatchMessageA
    jmp .loop

.render:
    call render_frame
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
    cmp edx, WM_DESTROY
    je .destroy
    cmp edx, WM_KEYDOWN
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
    cmp r8d, VK_ESCAPE
    je .esc
    cmp r8d, VK_W
    je .key_w
    cmp r8d, VK_S
    je .key_s
    cmp r8d, VK_A
    je .key_a
    cmp r8d, VK_D
    je .key_d
    cmp r8d, VK_Q
    je .key_q
    cmp r8d, VK_E
    je .key_e
    jmp .def

.esc:
    call DestroyWindow
    add rsp, 0x28
    xor eax, eax
    ret

.key_w:
    movss xmm0, [camDist]
    subss xmm0, [camSpeed]
    movss [camDist], xmm0
    jmp .key_done
.key_s:
    movss xmm0, [camDist]
    addss xmm0, [camSpeed]
    movss [camDist], xmm0
    jmp .key_done
.key_a:
    movss xmm0, [camYaw]
    subss xmm0, [rotSpeed]
    movss [camYaw], xmm0
    jmp .key_done
.key_d:
    movss xmm0, [camYaw]
    addss xmm0, [rotSpeed]
    movss [camYaw], xmm0
    jmp .key_done
.key_q:
    movss xmm0, [camPitch]
    subss xmm0, [rotSpeed]
    movss [camPitch], xmm0
    jmp .key_done
.key_e:
    movss xmm0, [camPitch]
    addss xmm0, [rotSpeed]
    movss [camPitch], xmm0

.key_done:
    add rsp, 0x28
    xor eax, eax
    ret
.def:
    add rsp, 0x28
    jmp DefWindowProcA

init_opengl:
    push rbx
    sub rsp, 0x20

    mov rcx, [hwnd]
    call GetDC
    test rax, rax
    jz .fail
    mov [hDC], rax

    mov rcx, [hDC]
    lea rdx, [pfd]
    call ChoosePixelFormat
    test eax, eax
    jz .fail_release
    mov ebx, eax

    mov rcx, [hDC]
    mov edx, ebx
    lea r8, [pfd]
    call SetPixelFormat
    test eax, eax
    jz .fail_release

    mov rcx, [hDC]
    call wglCreateContext
    test rax, rax
    jz .fail_release
    mov [hRC], rax


    mov rcx, [hDC]
    mov rdx, [hRC]
    call wglMakeCurrent
    test eax, eax
    jz .fail_context


    movss xmm0, [float_zero]
    movss xmm1, [float_zero]
    movss xmm2, [float_zero]
    movss xmm3, [float_one]
    call glClearColor

    mov ecx, GL_DEPTH_TEST
    call glEnable
    mov ecx, GL_LIGHTING
    call glEnable
    mov ecx, GL_LIGHT0
    call glEnable
    mov ecx, GL_SMOOTH
    call glShadeModel

    mov ecx, GL_LIGHT0
    mov edx, GL_POSITION
    lea r8, [lightPos]
    call glLightfv
    mov ecx, GL_LIGHT0
    mov edx, GL_AMBIENT
    lea r8, [lightAmb]
    call glLightfv
    mov ecx, GL_LIGHT0
    mov edx, GL_DIFFUSE
    lea r8, [lightDiff]
    call glLightfv
    mov ecx, GL_LIGHT0
    mov edx, GL_SPECULAR
    lea r8, [lightSpec]
    call glLightfv

    mov ecx, GL_FRONT
    mov edx, GL_AMBIENT
    lea r8, [matAmb]
    call glMaterialfv
    mov ecx, GL_FRONT
    mov edx, GL_DIFFUSE
    lea r8, [matDiff]
    call glMaterialfv
    mov ecx, GL_FRONT
    mov edx, GL_SPECULAR
    lea r8, [matSpec]
    call glMaterialfv
    mov ecx, GL_FRONT
    mov edx, GL_SHININESS
    lea r8, [matShin]
    call glMaterialfv

    xor ecx, ecx
    xor edx, edx
    mov r8d, WIDTH
    mov r9d, HEIGHT
    call glViewport

    mov ecx, GL_PROJECTION
    call glMatrixMode
    call glLoadIdentity

    sub rsp, 0x30
    movsd xmm0, [d_left]
    movsd xmm1, [d_right]
    movsd xmm2, [d_bottom]
    movsd xmm3, [d_top]
    movsd xmm4, [d_near]
    movsd xmm5, [d_far]
    movsd [rsp+32], xmm4
    movsd [rsp+40], xmm5
    call glFrustum
    add rsp, 0x30

    mov eax, 1
    add rsp, 0x20
    pop rbx
    ret

.fail_context:
    mov rcx, [hRC]
    call wglDeleteContext
.fail_release:
    mov rcx, [hwnd]
    mov rdx, [hDC]
    call ReleaseDC
.fail:
    xor eax, eax
    add rsp, 0x20
    pop rbx
    ret

render_frame:
    sub rsp, 0x38

    mov ecx, GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT
    call glClear

    mov ecx, GL_MODELVIEW
    call glMatrixMode
    call glLoadIdentity

    movss xmm0, [float_zero]
    movss xmm1, [float_zero]
    movss xmm2, [float_zero]
    subss xmm2, [camDist]
    call glTranslatef

    movss xmm0, [camPitch]
    movss xmm1, [float_one]
    movss xmm2, [float_zero]
    movss xmm3, [float_zero]
    call glRotatef

    movss xmm0, [camYaw]
    movss xmm1, [float_zero]
    movss xmm2, [float_one]
    movss xmm3, [float_zero]
    call glRotatef

    movss xmm0, [angleX]
    movss xmm1, [float_one]
    movss xmm2, [float_zero]
    movss xmm3, [float_zero]
    call glRotatef
    movss xmm0, [angleY]
    movss xmm1, [float_zero]
    movss xmm2, [float_one]
    movss xmm3, [float_zero]
    call glRotatef

    mov ecx, GL_QUADS
    call glBegin

    ; جلو قرمز
    movss xmm0, [float_one]
    movss xmm1, [float_zero]
    movss xmm2, [float_zero]
    call glColor3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_minus_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_minus_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_one]
    movss xmm2, [float_minus_one]
    call glVertex3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_one]
    movss xmm2, [float_minus_one]
    call glVertex3f

    ; پشت سبز
    movss xmm0, [float_zero]
    movss xmm1, [float_one]
    movss xmm2, [float_zero]
    call glColor3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_one]
    call glVertex3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_one]
    movss xmm2, [float_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_one]
    movss xmm2, [float_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_one]
    call glVertex3f

    ; چپ آبی
    movss xmm0, [float_zero]
    movss xmm1, [float_zero]
    movss xmm2, [float_one]
    call glColor3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_minus_one]
    call glVertex3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_one]
    call glVertex3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_one]
    movss xmm2, [float_one]
    call glVertex3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_one]
    movss xmm2, [float_minus_one]
    call glVertex3f

    ; راست زرد
    movss xmm0, [float_one]
    movss xmm1, [float_one]
    movss xmm2, [float_zero]
    call glColor3f
    movss xmm0, [float_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_minus_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_one]
    movss xmm2, [float_minus_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_one]
    movss xmm2, [float_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_one]
    call glVertex3f

    ; پایین ارغوانی
    movss xmm0, [float_one]
    movss xmm1, [float_zero]
    movss xmm2, [float_one]
    call glColor3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_minus_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_minus_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_one]
    call glVertex3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_one]
    call glVertex3f

    ; بالا فیروزه‌ای
    movss xmm0, [float_zero]
    movss xmm1, [float_one]
    movss xmm2, [float_one]
    call glColor3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_one]
    movss xmm2, [float_minus_one]
    call glVertex3f
    movss xmm0, [float_minus_one]
    movss xmm1, [float_one]
    movss xmm2, [float_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_one]
    movss xmm2, [float_one]
    call glVertex3f
    movss xmm0, [float_one]
    movss xmm1, [float_one]
    movss xmm2, [float_minus_one]
    call glVertex3f

    call glEnd

    movss xmm0, [angleX]
    addss xmm0, [deltaX]
    movss [angleX], xmm0
    movss xmm0, [angleY]
    addss xmm0, [deltaY]
    movss [angleY], xmm0

    mov rcx, [hDC]
    call SwapBuffers

    add rsp, 0x38
    ret
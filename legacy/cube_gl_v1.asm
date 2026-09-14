
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

section .data
align 16
className db "OpenGLCube",0
windowTitle db "OpenGL Cube - WASD+QE, Esc exit",0

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
    dw 44
    dw 1
    dd 0x00000004 | 0x00000020 | 0x00000001   ; PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER
    db 0                                        ; PFD_TYPE_RGBA
    db 32                                       ; cColorBits
    db 0,0,0,0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,0,0,0,0,0,0
    db 24
    db 0
    db 0
    db 0
    db 0
    dd 0
    dd 0
    dd 0

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

WinMain:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x40

    xor ecx, ecx
    call GetModuleHandleA
    mov [hInstance], rax

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
    call init_opengl
    test eax, eax
    jz .exit

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
    je .esc
    cmp r8d, 0x57                ; VK_W
    je .key_w
    cmp r8d, 0x53                ; VK_S
    je .key_s
    cmp r8d, 0x41                ; VK_A
    je .key_a
    cmp r8d, 0x44                ; VK_D
    je .key_d
    cmp r8d, 0x51                ; VK_Q
    je .key_q
    cmp r8d, 0x45                ; VK_E
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
    mov rdx, rax
    call wglMakeCurrent
    test eax, eax
    jz .fail_context

    movss xmm0, [float_zero]
    movss xmm1, [float_zero]
    movss xmm2, [float_zero]
    movss xmm3, [float_one]
    call glClearColor

    mov ecx, 0x0B71              ; GL_DEPTH_TEST
    call glEnable
    mov ecx, 0x0B50              ; GL_LIGHTING
    call glEnable
    mov ecx, 0x4000              ; GL_LIGHT0
    call glEnable
    mov ecx, 0x1D01              ; GL_SMOOTH
    call glShadeModel

    mov ecx, 0x4000              ; GL_LIGHT0
    mov edx, 0x1203              ; GL_POSITION
    lea r8, [lightPos]
    call glLightfv
    mov ecx, 0x4000
    mov edx, 0x1200              ; GL_AMBIENT
    lea r8, [lightAmb]
    call glLightfv
    mov ecx, 0x4000
    mov edx, 0x1201              ; GL_DIFFUSE
    lea r8, [lightDiff]
    call glLightfv
    mov ecx, 0x4000
    mov edx, 0x1202              ; GL_SPECULAR
    lea r8, [lightSpec]
    call glLightfv

    mov ecx, 0x0404              ; GL_FRONT
    mov edx, 0x1200              ; GL_AMBIENT
    lea r8, [matAmb]
    call glMaterialfv
    mov ecx, 0x0404
    mov edx, 0x1201              ; GL_DIFFUSE
    lea r8, [matDiff]
    call glMaterialfv
    mov ecx, 0x0404
    mov edx, 0x1202              ; GL_SPECULAR
    lea r8, [matSpec]
    call glMaterialfv
    mov ecx, 0x0404
    mov edx, 0x1601              ; GL_SHININESS
    lea r8, [matShin]
    call glMaterialfv

    xor ecx, ecx
    xor edx, edx
    mov r8d, WIDTH
    mov r9d, HEIGHT
    call glViewport

    mov ecx, 0x1701              ; GL_PROJECTION
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

    mov ecx, 0x00004000 | 0x00000100   ; GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT
    call glClear

    mov ecx, 0x1700              ; GL_MODELVIEW
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

    mov ecx, 0x0007              ; GL_QUADS
    call glBegin


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
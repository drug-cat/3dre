
BITS 64
default rel

%define WIDTH 800
%define HEIGHT 600
%define GROUND_Y -1.0


%define VK_ESCAPE 0x1B
%define VK_W 0x57
%define VK_S 0x53
%define VK_A 0x41
%define VK_D 0x44
%define VK_Q 0x51
%define VK_E 0x45
%define VK_LEFT 0x25
%define VK_UP 0x26
%define VK_RIGHT 0x27
%define VK_DOWN 0x28
%define VK_PRIOR 0x21    ; PageUp
%define VK_NEXT 0x22     ; PageDown
%define VK_M 0x4D
%define VK_1 0x31
%define VK_2 0x32

; OpenGL
%define GL_COLOR_BUFFER_BIT 0x00004000
%define GL_DEPTH_BUFFER_BIT 0x00000100
%define GL_STENCIL_BUFFER_BIT 0x00000400
%define GL_MODELVIEW 0x1700
%define GL_PROJECTION 0x1701
%define GL_DEPTH_TEST 0x0B71
%define GL_LIGHTING 0x0B50
%define GL_LIGHT0 0x4000
%define GL_FLAT 0x1D00
%define GL_SMOOTH 0x1D01
%define GL_FRONT 0x0404
%define GL_AMBIENT 0x1200
%define GL_DIFFUSE 0x1201
%define GL_SPECULAR 0x1202
%define GL_POSITION 0x1203
%define GL_SHININESS 0x1601
%define GL_QUADS 0x0007
%define GL_TRIANGLES 0x0004
%define GL_COLOR_MATERIAL 0x0B57
%define GL_AMBIENT_AND_DIFFUSE 0x1602
%define GL_LIGHT_MODEL_AMBIENT 0x0B52
%define GL_POLYGON_OFFSET_FILL 0x8037
%define GL_FRONT_AND_BACK 0x0408
%define GL_FILL 0x1B02
%define GL_LINE 0x1B01

; PFD
%define PFD_TYPE_RGBA 0
%define PFD_MAIN_PLANE 0
%define PFD_DOUBLEBUFFER 0x00000001
%define PFD_DRAW_TO_WINDOW 0x00000004
%define PFD_SUPPORT_OPENGL 0x00000020

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
extern glPushMatrix
extern glPopMatrix
extern glMultMatrixf
extern glEnable
extern glDisable
extern glShadeModel
extern glLightfv
extern glLightModelfv
extern glMaterialfv
extern glColorMaterial
extern glBegin
extern glColor3f
extern glVertex3f
extern glEnd
extern glPolygonOffset
extern glPolygonMode

section .data
align 16
className db "EngineDemo",0
windowTitle db "Engine Demo - WASD+QE camera, arrows light, M wireframe, 1/2 mesh",0

align 16
lightPos     dd 0.0, 5.0, 0.0, 1.0    
lightAmb     dd 0.2, 0.2, 0.2, 1.0
lightDiff    dd 1.0, 1.0, 1.0, 1.0
lightSpec    dd 1.0, 1.0, 1.0, 1.0
globalAmb    dd 0.1, 0.1, 0.1, 1.0

matAmb      dd 0.3, 0.3, 0.3, 1.0
matDiff     dd 1.0, 1.0, 1.0, 1.0
matSpec     dd 1.0, 1.0, 1.0, 1.0
matShin     dd 128.0

align 16
pfd:
    dw 44
    dw 1
    dd PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER
    db PFD_TYPE_RGBA
    db 32
    db 0,0,0,0,0,0,0,0
    db 0,0,0,0,0
    db 0,0,0,0,0,0,0,0
    db 24
    db 8
    db 0
    db 0
    db 0
    dd 0
    dd 0
    dd 0

align 16
float_one       dd 1.0
float_zero      dd 0.0
float_minus_one dd -1.0
float_5         dd 5.0
float_minus_5   dd -5.0
float_half      dd 0.5
float_minus_half dd -0.5

align 16
d_left   dq -1.333
d_right  dq  1.333
d_bottom dq -1.0
d_top    dq  1.0
d_near   dq  1.5
d_far    dq  50.0


camDist     dd 14.0
camYaw      dd 0.0
camPitch    dd 0.35
camSpeed    dd 0.3
rotSpeed    dd 1.5

lightSpeed  dd 0.2


sphereRadius dd 1.0
sphereSlices dd 16
sphereStacks dd 16
spherePos    dd 0.0, 2.0, 0.0


wireframeMode dd 0


cubePositions:
    dd  0.0, -1.0,  0.0
    dd  0.0,  1.0,  0.0
    dd -2.0, -1.0,  2.0
    dd  2.0, -1.0,  2.0
    dd -2.0, -1.0, -2.0
    dd  2.0, -1.0, -2.0

NUM_CUBES equ 6

section .bss
align 16
hInstance resq 1
hwnd resq 1
hDC resq 1
hRC resq 1
wcex resb 80
rect resb 16
msg resb 48

shadowMatrix resd 16

section .text
global WinMain

; ======================= Main =======================
WinMain:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x40

    xor ecx, ecx
    call GetModuleHandleA
    mov [hInstance], rax

    ; Register window
    mov dword [wcex+0], 80
    mov dword [wcex+4], 0x0002 | 0x0001 | 0x0020
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
    mov rdx, 0x00CF0000
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
    mov r10d, 0x80000000
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
    mov edx, 5
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
    mov dword [rsp+32], 1
    call PeekMessageA
    add rsp, 0x30
    test eax, eax
    jz .render

    cmp dword [msg+8], 0x0012
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

; ======================= Window Procedure =======================
WndProc:
    sub rsp, 0x28
    cmp edx, 0x0002
    je .destroy
    cmp edx, 0x0100
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
    cmp r8d, VK_LEFT
    je .key_left
    cmp r8d, VK_RIGHT
    je .key_right
    cmp r8d, VK_UP
    je .key_up
    cmp r8d, VK_DOWN
    je .key_down
    cmp r8d, VK_PRIOR
    je .key_prior
    cmp r8d, VK_NEXT
    je .key_next
    cmp r8d, VK_M
    je .key_m
    cmp r8d, VK_1
    je .key_1
    cmp r8d, VK_2
    je .key_2
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
    jmp .key_done

.key_left:
    movss xmm0, [lightPos]
    subss xmm0, [lightSpeed]
    movss [lightPos], xmm0
    jmp .key_done
.key_right:
    movss xmm0, [lightPos]
    addss xmm0, [lightSpeed]
    movss [lightPos], xmm0
    jmp .key_done
.key_up:
    movss xmm0, [lightPos+8]
    subss xmm0, [lightSpeed]
    movss [lightPos+8], xmm0
    jmp .key_done
.key_down:
    movss xmm0, [lightPos+8]
    addss xmm0, [lightSpeed]
    movss [lightPos+8], xmm0
    jmp .key_done
.key_prior:
    movss xmm0, [lightPos+4]
    addss xmm0, [lightSpeed]
    movss [lightPos+4], xmm0
    jmp .key_done
.key_next:
    movss xmm0, [lightPos+4]
    subss xmm0, [lightSpeed]
    movss [lightPos+4], xmm0
    jmp .key_done

.key_m:
    mov eax, [wireframeMode]
    xor eax, 1
    mov [wireframeMode], eax
    jmp .key_done

.key_1:
    
    mov eax, [sphereSlices]
    sub eax, 2
    cmp eax, 4
    jge .set_slices
    mov eax, 4
.set_slices:
    mov [sphereSlices], eax
    mov eax, [sphereStacks]
    sub eax, 2
    cmp eax, 4
    jge .set_stacks
    mov eax, 4
.set_stacks:
    mov [sphereStacks], eax
    jmp .key_done

.key_2:
    
    mov eax, [sphereSlices]
    add eax, 2
    cmp eax, 64
    jle .set_slices2
    mov eax, 64
.set_slices2:
    mov [sphereSlices], eax
    mov eax, [sphereStacks]
    add eax, 2
    cmp eax, 64
    jle .set_stacks2
    mov eax, 64
.set_stacks2:
    mov [sphereStacks], eax

.key_done:
    add rsp, 0x28
    xor eax, eax
    ret
.def:
    add rsp, 0x28
    jmp DefWindowProcA

; ======================= OpenGL Initialization =======================
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

    ; Clear color
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
    ; GL_FLAT برای رنگ یکنواخت وجه‌ها
    mov ecx, GL_FLAT
    call glShadeModel

    mov ecx, GL_COLOR_MATERIAL
    call glEnable
    mov ecx, GL_FRONT
    mov edx, GL_AMBIENT_AND_DIFFUSE
    call glColorMaterial

    mov ecx, GL_LIGHT_MODEL_AMBIENT
    lea rdx, [globalAmb]
    call glLightModelfv

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

; ======================= Shadow Matrix =======================
compute_shadow_matrix:
    push rbx
    sub rsp, 0x20

    movss xmm0, [lightPos]
    movss xmm1, [lightPos+4]
    movss xmm2, [lightPos+8]
    movss xmm5, [float_one]      ; d=1.0

    movss xmm6, xmm1
    addss xmm6, xmm5             ; ly+d

    movss [shadowMatrix+0], xmm6
    xorps xmm7, xmm7
    movss [shadowMatrix+4], xmm7
    movss [shadowMatrix+8], xmm7
    movss [shadowMatrix+12], xmm7

    xorps xmm9, xmm9
    subss xmm9, xmm0
    movss [shadowMatrix+16], xmm9   ; -lx
    movss [shadowMatrix+20], xmm5   ; d=1.0
    xorps xmm9, xmm9
    subss xmm9, xmm2
    movss [shadowMatrix+24], xmm9   ; -lz
    movss xmm8, [float_one]
    xorps xmm9, xmm9
    subss xmm9, xmm8
    movss [shadowMatrix+28], xmm9   ; -1

    xorps xmm7, xmm7
    movss [shadowMatrix+32], xmm7
    movss [shadowMatrix+36], xmm7
    movss [shadowMatrix+40], xmm6
    movss [shadowMatrix+44], xmm7

    movss xmm8, xmm0
    mulss xmm8, xmm5
    xorps xmm9, xmm9
    subss xmm9, xmm8
    movss [shadowMatrix+48], xmm9   ; -lx*d
    movss xmm8, xmm1
    mulss xmm8, xmm5
    xorps xmm9, xmm9
    subss xmm9, xmm8
    movss [shadowMatrix+52], xmm9   ; -ly*d
    movss xmm8, xmm2
    mulss xmm8, xmm5
    xorps xmm9, xmm9
    subss xmm9, xmm8
    movss [shadowMatrix+56], xmm9   ; -lz*d
    movss [shadowMatrix+60], xmm1   ; ly

    add rsp, 0x20
    pop rbx
    ret

; ======================= Draw Cube =======================
draw_cube:
    sub rsp, 0x28
    mov ecx, GL_QUADS
    call glBegin

    ; Front face (red)
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

    ; Back face (green)
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

    ; Left face (blue)
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

    ; Right face (yellow)
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

    ; Bottom face (magenta)
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

    ; Top face (cyan)
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
    add rsp, 0x28
    ret

; ======================= Draw Cube Shadow (Black) =======================
draw_cube_black:
    sub rsp, 0x28
    mov ecx, GL_QUADS
    call glBegin
    ; Front
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
    ; Back
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
    ; Left
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
    ; Right
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
    ; Bottom
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
    ; Top
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
    add rsp, 0x28
    ret

; ======================= Draw Sphere (with color) =======================
draw_sphere:
    sub rsp, 0x38
    movss xmm0, [float_zero]
    movss xmm1, [float_one]
    movss xmm2, [float_zero]
    call glColor3f

    add rsp, 0x38
    ret

; ======================= Render Frame =======================
render_frame:
    sub rsp, 0x38

    
    
    call compute_shadow_matrix

    ; Clear
    mov ecx, GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT
    call glClear

    ; Modelview
    mov ecx, GL_MODELVIEW
    call glMatrixMode
    call glLoadIdentity

    ; Camera
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

    
    mov eax, [wireframeMode]
    test eax, eax
    jz .fill_mode
    mov ecx, GL_FRONT_AND_BACK
    mov edx, GL_LINE
    call glPolygonMode
    jmp .mode_set
.fill_mode:
    mov ecx, GL_FRONT_AND_BACK
    mov edx, GL_FILL
    call glPolygonMode
.mode_set:

    ; Draw ground (green)
    mov ecx, GL_QUADS
    call glBegin
    movss xmm0, [float_zero]
    movss xmm1, [float_one]
    movss xmm2, [float_zero]
    call glColor3f
    movss xmm0, [float_minus_5]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_minus_5]
    call glVertex3f
    movss xmm0, [float_5]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_minus_5]
    call glVertex3f
    movss xmm0, [float_5]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_5]
    call glVertex3f
    movss xmm0, [float_minus_5]
    movss xmm1, [float_minus_one]
    movss xmm2, [float_5]
    call glVertex3f
    call glEnd

    ; Draw cubes
    mov r12d, NUM_CUBES
    lea r13, [cubePositions]
.draw_cubes_loop:
    call glPushMatrix
    movss xmm0, [r13]
    movss xmm1, [r13+4]
    movss xmm2, [r13+8]
    call glTranslatef
    call draw_cube
    call glPopMatrix
    add r13, 12
    dec r12d
    jnz .draw_cubes_loop

    
    mov ecx, GL_LIGHTING
    call glDisable
    mov ecx, GL_POLYGON_OFFSET_FILL
    call glEnable
    movss xmm0, [float_minus_one]
    movss xmm1, [float_minus_one]
    call glPolygonOffset
    movss xmm0, [float_zero]
    movss xmm1, [float_zero]
    movss xmm2, [float_zero]
    call glColor3f

    call glPushMatrix
    lea rcx, [shadowMatrix]   
    call glMultMatrixf


    mov r12d, NUM_CUBES
    lea r13, [cubePositions]
.draw_shadow_loop:
    call glPushMatrix
    movss xmm0, [r13]
    movss xmm1, [r13+4]
    movss xmm2, [r13+8]
    call glTranslatef
    call draw_cube_black
    call glPopMatrix
    add r13, 12
    dec r12d
    jnz .draw_shadow_loop

    call glPopMatrix

    mov ecx, GL_POLYGON_OFFSET_FILL
    call glDisable
    mov ecx, GL_LIGHTING
    call glEnable


    mov ecx, GL_FRONT_AND_BACK
    mov edx, GL_FILL
    call glPolygonMode


    mov rcx, [hDC]
    call SwapBuffers

    add rsp, 0x38
    ret
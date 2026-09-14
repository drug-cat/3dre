; ============================================================
; src/main.asm
; Rotating cube + FPS camera with mouse look
; ============================================================
BITS 64
default rel

%include "win32.inc"
%include "gl.inc"
%include "math.inc"
%include "input.inc"

; ---- GL 3.3 pointers ----
extern glCreateShader
extern glShaderSource
extern glCompileShader
extern glCreateProgram
extern glAttachShader
extern glLinkProgram
extern glUseProgram
extern glDeleteShader
extern glGenVertexArrays
extern glBindVertexArray
extern glGenBuffers
extern glBindBuffer
extern glBufferData
extern glVertexAttribPointer
extern glEnableVertexAttribArray
extern glDrawElements
extern glGetUniformLocation
extern glUniformMatrix4fv

; ---- GL 1.1 direct ----
extern glClear
extern glClearColor
extern glEnable
extern glCullFace
extern glFrontFace

; ---- Engine ----
extern win32_register_class
extern win32_create_window
extern win32_create_gl_context
extern win32_destroy_gl_context
extern win32_swap_buffers
extern gl_load_functions

extern input_init
extern input_on_key_down
extern input_on_key_up
extern input_end_frame
extern input_enable_mouse_look
extern input_disable_mouse_look
extern input_poll_mouse

extern camera_get_view
extern camera_get_proj
extern camera_update

extern mat4_mul
extern mat4_make_rotate_y

; ---- Win32 ----
extern GetModuleHandleA
extern ShowWindow
extern UpdateWindow
extern PeekMessageA
extern TranslateMessage
extern DispatchMessageA
extern DefWindowProcA
extern PostQuitMessage
extern DestroyWindow
extern GetTickCount64

extern input_mouse_is_active

global WinMain

; ============================================================
section .data
align 16

window_title db "3dre - FPS Camera Demo",0

vertex_shader_src:
    db "#version 330 core",13,10
    db "layout(location = 0) in vec3 aPos;",13,10
    db "layout(location = 1) in vec3 aColor;",13,10
    db "uniform mat4 uMVP;",13,10
    db "out vec3 vColor;",13,10
    db "void main() {",13,10
    db "    gl_Position = uMVP * vec4(aPos, 1.0);",13,10
    db "    vColor = aColor;",13,10
    db "}",0

fragment_shader_src:
    db "#version 330 core",13,10
    db "in vec3 vColor;",13,10
    db "out vec4 FragColor;",13,10
    db "void main() {",13,10
    db "    FragColor = vec4(vColor, 1.0);",13,10
    db "}",0

uniform_mvp_name db "uMVP",0

align 16
cube_vertices:
    ; -Z (red)
    dd -0.5, -0.5, -0.5,   1.0, 0.0, 0.0
    dd  0.5, -0.5, -0.5,   1.0, 0.0, 0.0
    dd  0.5,  0.5, -0.5,   1.0, 0.0, 0.0
    dd -0.5,  0.5, -0.5,   1.0, 0.0, 0.0
    ; +Z (green)
    dd -0.5, -0.5,  0.5,   0.0, 1.0, 0.0
    dd  0.5, -0.5,  0.5,   0.0, 1.0, 0.0
    dd  0.5,  0.5,  0.5,   0.0, 1.0, 0.0
    dd -0.5,  0.5,  0.5,   0.0, 1.0, 0.0
    ; -Y (blue)
    dd -0.5, -0.5, -0.5,   0.0, 0.0, 1.0
    dd  0.5, -0.5, -0.5,   0.0, 0.0, 1.0
    dd  0.5, -0.5,  0.5,   0.0, 0.0, 1.0
    dd -0.5, -0.5,  0.5,   0.0, 0.0, 1.0
    ; +Y (yellow)
    dd -0.5,  0.5, -0.5,   1.0, 1.0, 0.0
    dd  0.5,  0.5, -0.5,   1.0, 1.0, 0.0
    dd  0.5,  0.5,  0.5,   1.0, 1.0, 0.0
    dd -0.5,  0.5,  0.5,   1.0, 1.0, 0.0
    ; -X (magenta)
    dd -0.5, -0.5, -0.5,   1.0, 0.0, 1.0
    dd -0.5, -0.5,  0.5,   1.0, 0.0, 1.0
    dd -0.5,  0.5,  0.5,   1.0, 0.0, 1.0
    dd -0.5,  0.5, -0.5,   1.0, 0.0, 1.0
    ; +X (cyan)
    dd  0.5, -0.5, -0.5,   0.0, 1.0, 1.0
    dd  0.5, -0.5,  0.5,   0.0, 1.0, 1.0
    dd  0.5,  0.5,  0.5,   0.0, 1.0, 1.0
    dd  0.5,  0.5, -0.5,   0.0, 1.0, 1.0

align 16
cube_indices:
    dd 0,2,1, 0,3,2
    dd 4,5,6, 4,6,7
    dd 8,9,10, 8,10,11
    dd 12,14,13, 12,15,14
    dd 16,17,18, 16,18,19
    dd 20,22,21, 20,23,22

align 16
f_1_0:      dd 1.0
f_0_01:     dd 0.01
bg_rgb:     dd 0.15
rot_speed:  dd 0.8

; ============================================================
section .bss
align 16

hInstance       resq 1
hwnd            resq 1
msg             resb 48

shader_program  resd 1
vao             resd 1
vbo             resd 1
ebo             resd 1
u_mvp_loc       resd 1

align 16
mat_model       resb 64
mat_view        resb 64
mat_proj        resb 64
mat_tmp         resb 64
mat_mvp         resb 64

angle_y         resd 1
last_tick       resq 1
dt_seconds      resd 1

; ============================================================
section .text

WinMain:
    push rbx
    push rsi
    push rdi
    sub  rsp, 0x40

    xor  ecx, ecx
    call GetModuleHandleA
    test rax, rax
    jz   .exit
    mov  [hInstance], rax

    mov  rcx, rax
    lea  rdx, [WndProc]
    xor  r8d, r8d
    call win32_register_class
    test eax, eax
    jz   .exit

    mov  rcx, [hInstance]
    lea  rdx, [window_title]
    mov  r8d, 800
    mov  r9d, 600
    call win32_create_window
    test rax, rax
    jz   .exit
    mov  [hwnd], rax

    mov  rcx, rax
    mov  edx, SW_SHOW
    call ShowWindow
    mov  rcx, [hwnd]
    call UpdateWindow

    ; ; ---- Enable mouse look after window is created ----
    ; mov  rcx, [hwnd]
    ; call input_enable_mouse_look

    mov  rcx, [hwnd]
    call win32_create_gl_context
    test eax, eax
    jz   .exit

    call gl_load_functions
    test eax, eax
    jz   .exit

    call input_init
    call renderer_init

    call GetTickCount64
    mov  [last_tick], rax
    mov  dword [angle_y], 0

.loop:
    sub  rsp, 0x30
    lea  rcx, [msg]
    xor  edx, edx
    xor  r8d, r8d
    xor  r9d, r9d
    mov  dword [rsp+0x20], PM_REMOVE
    call PeekMessageA
    add  rsp, 0x30
    test eax, eax
    jz   .render

    cmp  dword [msg+8], WM_QUIT
    je   .exit
    lea  rcx, [msg]
    call TranslateMessage
    lea  rcx, [msg]
    call DispatchMessageA
    jmp  .loop

.render:
    call update_time
    call input_poll_mouse
    movss xmm0, [dt_seconds]
    call camera_update
    call renderer_draw
    call input_end_frame
    jmp  .loop

.exit:
    call input_disable_mouse_look
    call win32_destroy_gl_context
    add  rsp, 0x40
    pop  rdi
    pop  rsi
    pop  rbx
    xor  eax, eax
    ret

; ============================================================
update_time:
    sub  rsp, 0x28
    call GetTickCount64
    mov  rcx, rax
    sub  rax, [last_tick]
    mov  [last_tick], rcx
    test rax, rax
    jnz  .have_ms
    mov  rax, 1
.have_ms:
    cmp  rax, 33
    jbe  .ok_ms
    mov  rax, 33
.ok_ms:
    cvtsi2ss xmm0, rax
    mulss xmm0, [f_0_01]
    movss [dt_seconds], xmm0
    add  rsp, 0x28
    ret

; ============================================================
WndProc:
    sub  rsp, 0x28

    cmp  edx, WM_DESTROY
    je   .destroy
    cmp  edx, WM_ACTIVATE
    je   .activate
    cmp  edx, WM_KEYDOWN
    je   .keydown
    cmp  edx, WM_KEYUP
    je   .keyup
    cmp  edx, WM_SETCURSOR
    je   .setcursor

    add  rsp, 0x28
    jmp  DefWindowProcA

.destroy:
    call input_disable_mouse_look
    xor  ecx, ecx
    call PostQuitMessage
    add  rsp, 0x28
    xor  eax, eax
    ret

.activate:
    ; wParam low word: WA_INACTIVE=0, WA_ACTIVE=1, WA_CLICKACTIVE=2
    movzx eax, r8w
    test  eax, eax
    jz    .deactivate
    mov   rcx, [hwnd]
    call  input_enable_mouse_look
    add   rsp, 0x28
    xor   eax, eax
    ret
.deactivate:
    call  input_disable_mouse_look
    add   rsp, 0x28
    xor   eax, eax
    ret

.keydown:
    cmp  r8d, VK_ESCAPE
    je   .esc
    mov  ecx, r8d
    mov  rdx, r9
    call input_on_key_down
    add  rsp, 0x28
    jmp  DefWindowProcA

.keyup:
    mov  ecx, r8d
    call input_on_key_up
    add  rsp, 0x28
    jmp  DefWindowProcA

.setcursor:
    call input_mouse_is_active
    test eax, eax
    jz   .setcursor_default
    mov  eax, 1
    add  rsp, 0x28
    ret
.setcursor_default:
    add  rsp, 0x28
    jmp  DefWindowProcA

.esc:
    mov  rcx, [hwnd]
    call DestroyWindow
    add  rsp, 0x28
    xor  eax, eax
    ret

; ============================================================
renderer_init:
    push rbx
    push rsi
    push rdi
    sub  rsp, 0x30

    ; Vertex shader
    mov  ecx, GL_VERTEX_SHADER
    call qword [glCreateShader]
    test eax, eax
    jz   .done
    mov  ebx, eax

    lea  rax, [vertex_shader_src]
    mov  [rsp+0x20], rax
    mov  rcx, rbx
    mov  edx, 1
    lea  r8,  [rsp+0x20]
    xor  r9d, r9d
    call qword [glShaderSource]

    mov  rcx, rbx
    call qword [glCompileShader]

    ; Fragment shader
    mov  ecx, GL_FRAGMENT_SHADER
    call qword [glCreateShader]
    test eax, eax
    jz   .done
    mov  esi, eax

    lea  rax, [fragment_shader_src]
    mov  [rsp+0x20], rax
    mov  rcx, rsi
    mov  edx, 1
    lea  r8,  [rsp+0x20]
    xor  r9d, r9d
    call qword [glShaderSource]

    mov  rcx, rsi
    call qword [glCompileShader]

    ; Link
    call qword [glCreateProgram]
    test eax, eax
    jz   .done
    mov  edi, eax

    mov  rcx, rdi
    mov  edx, ebx
    call qword [glAttachShader]
    mov  rcx, rdi
    mov  edx, esi
    call qword [glAttachShader]

    mov  rcx, rdi
    call qword [glLinkProgram]
    mov  rcx, rdi
    call qword [glUseProgram]
    mov  [shader_program], edi

    mov  rcx, rbx
    call qword [glDeleteShader]
    mov  rcx, rsi
    call qword [glDeleteShader]

    ; uMVP location
    mov  rcx, rdi
    lea  rdx, [uniform_mvp_name]
    call qword [glGetUniformLocation]
    mov  [u_mvp_loc], eax

    ; VAO
    mov  ecx, 1
    lea  rdx, [vao]
    call qword [glGenVertexArrays]
    mov  ecx, [vao]
    call qword [glBindVertexArray]

    ; VBO
    mov  ecx, 1
    lea  rdx, [vbo]
    call qword [glGenBuffers]
    mov  ecx, GL_ARRAY_BUFFER
    mov  edx, [vbo]
    call qword [glBindBuffer]

    mov  ecx, GL_ARRAY_BUFFER
    mov  edx, 24 * 6 * 4
    lea  r8,  [cube_vertices]
    mov  r9d, GL_STATIC_DRAW
    call qword [glBufferData]

    ; aPos
    mov  ecx, 0
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], 24
    mov  qword [rsp+0x28], 0
    call qword [glVertexAttribPointer]
    mov  ecx, 0
    call qword [glEnableVertexAttribArray]

    ; aColor
    mov  ecx, 1
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], 24
    mov  qword [rsp+0x28], 12
    call qword [glVertexAttribPointer]
    mov  ecx, 1
    call qword [glEnableVertexAttribArray]

    ; EBO
    mov  ecx, 1
    lea  rdx, [ebo]
    call qword [glGenBuffers]
    mov  ecx, GL_ELEMENT_ARRAY_BUFFER
    mov  edx, [ebo]
    call qword [glBindBuffer]

    mov  ecx, GL_ELEMENT_ARRAY_BUFFER
    mov  edx, 36 * 4
    lea  r8,  [cube_indices]
    mov  r9d, GL_STATIC_DRAW
    call qword [glBufferData]

    ; GL state
    mov  ecx, GL_DEPTH_TEST
    call glEnable
    mov  ecx, GL_CULL_FACE
    call glEnable
    mov  ecx, GL_BACK
    call glCullFace
    mov  ecx, GL_CCW
    call glFrontFace

.done:
    add  rsp, 0x30
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
renderer_draw:
    sub  rsp, 0x28

    ; Animate
    movss xmm0, [dt_seconds]
    mulss xmm0, [rot_speed]
    addss xmm0, [angle_y]
    movss [angle_y], xmm0

    lea  rcx, [mat_proj]
    call camera_get_proj

    lea  rcx, [mat_view]
    call camera_get_view

    lea  rcx, [mat_model]
    movss xmm0, [angle_y]
    call mat4_make_rotate_y

    lea  rcx, [mat_tmp]
    lea  rdx, [mat_view]
    lea  r8,  [mat_model]
    call mat4_mul

    lea  rcx, [mat_mvp]
    lea  rdx, [mat_proj]
    lea  r8,  [mat_tmp]
    call mat4_mul

    movss xmm0, [bg_rgb]
    movss xmm1, [bg_rgb]
    movss xmm2, [bg_rgb]
    movss xmm3, [f_1_0]
    call glClearColor

    mov  ecx, GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT
    call glClear

    mov  ecx, [u_mvp_loc]
    mov  edx, 1
    xor  r8d, r8d
    lea  r9,  [mat_mvp]
    call qword [glUniformMatrix4fv]

    mov  ecx, [vao]
    call qword [glBindVertexArray]
    mov  ecx, GL_TRIANGLES
    mov  edx, 36
    mov  r8d, GL_UNSIGNED_INT
    xor  r9d, r9d
    call qword [glDrawElements]

    call win32_swap_buffers
    add  rsp, 0x28
    ret
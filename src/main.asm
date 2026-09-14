; ============================================================
; src/main.asm
; Multiple cubes with directional lighting
; ============================================================
BITS 64
default rel

%include "win32.inc"
%include "gl.inc"
%include "math.inc"
%include "input.inc"
%include "shader.inc"
%include "mesh.inc"

; ---- GL 3.3 pointers ----
extern glBindVertexArray
extern glDrawElements

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
extern input_mouse_is_active

extern camera_get_view
extern camera_get_proj
extern camera_update

extern mat4_mul
extern mat4_make_translate
extern mat4_make_rotate_y

extern path_join_exe

extern shader_program_init
extern shader_program_hot_reload
extern shader_program_use
extern shader_program_destroy
extern shader_set_mat4
extern shader_set_vec3
extern shader_set_float

extern mesh_create_cube
extern mesh_draw
extern mesh_destroy

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
extern MessageBoxA

global WinMain

; ============================================================
section .data
align 16

window_title db "3dre - Lit Cubes",0
rel_vs_path  db "shaders\basic.vert",0
rel_fs_path  db "shaders\basic.frag",0

u_mvp_name       db "uMVP",0
u_model_name     db "uModel",0
u_light_dir_name db "uLightDir",0
u_light_col_name db "uLightColor",0
u_ambient_name   db "uAmbient",0

dbg_title       db "3dre Error",0
dbg_shader_fail db "Shader failed to load.",13,10,13,10
                db "Check that build/shaders/ contains basic.vert and basic.frag.",0

; ---- Light settings ----
align 16
light_dir        dd 0.4, 0.7, 0.5           ; direction FROM surface TO light
light_color      dd 1.0, 1.0, 1.0
ambient_level    dd 0.25

; ---- Instance list (32 bytes each) ----
;   +0   f32 x, y, z
;   +12  pad
;   +16  f32 angle_y
;   +20  f32 rot_speed
;   +24  pad, pad
align 16
instances:
    dd  0.0,  0.0, 0.0,  0.0,    0.0,   0.5,  0.0, 0.0
    dd  2.0,  0.0, 0.0,  0.0,    0.4,   0.7,  0.0, 0.0
    dd -2.0,  0.0, 0.0,  0.0,    0.8,   0.9,  0.0, 0.0
    dd  0.0,  2.0, 0.0,  0.0,    1.2,   0.5,  0.0, 0.0
    dd  0.0, -2.0, 0.0,  0.0,    1.6,   0.7,  0.0, 0.0

NUM_INSTANCES equ 5
INSTANCE_SIZE equ 32

align 16
f_1_0:      dd 1.0
f_0_01:     dd 0.01
bg_rgb:     dd 0.15

; ============================================================
section .bss

hInstance       resq 1
hwnd            resq 1
msg             resb 48

abs_vs_path     resb 260
abs_fs_path     resb 260

shader_prog     resb SP_SIZE
cube_mesh       resb MESH_SIZE

mat_proj        resb 64
mat_view        resb 64
mat_pv          resb 64
mat_tmp         resb 64
mat_tmp2        resb 64
mat_model       resb 64
mat_mvp         resb 64

last_tick       resq 1
dt_seconds      resd 1

; ============================================================
section .text

; ============================================================
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

    mov  rcx, [hwnd]
    call win32_create_gl_context
    test eax, eax
    jz   .exit

    call gl_load_functions
    test eax, eax
    jz   .exit

    call input_init
    call renderer_init

    lea  rax, [shader_prog]
    cmp  dword [rax+SP_ID], 0
    jne  .shader_ok

    sub  rsp, 0x20
    xor  ecx, ecx
    lea  rdx, [dbg_shader_fail]
    lea  r8,  [dbg_title]
    mov  r9d, 0x10
    call MessageBoxA
    add  rsp, 0x20
    jmp  .exit

.shader_ok:
    call GetTickCount64
    mov  [last_tick], rax

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
    lea  rcx, [cube_mesh]
    call mesh_destroy
    lea  rcx, [shader_prog]
    call shader_program_destroy
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
    add  rsp, 0x28
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
    sub  rsp, 0x20

    ; ---- Shader paths ----
    lea  rcx, [rel_vs_path]
    lea  rdx, [abs_vs_path]
    mov  r8d, 260
    call path_join_exe

    lea  rcx, [rel_fs_path]
    lea  rdx, [abs_fs_path]
    mov  r8d, 260
    call path_join_exe

    ; ---- Shader program ----
    lea  rcx, [shader_prog]
    lea  rdx, [abs_vs_path]
    lea  r8,  [abs_fs_path]
    call shader_program_init
    test eax, eax
    jz   .no_shader

    lea  rcx, [shader_prog]
    call shader_program_use

    ; ---- Set light uniforms once ----
    lea  rcx, [shader_prog]
    lea  rdx, [u_light_dir_name]
    lea  r8,  [light_dir]
    call shader_set_vec3

    lea  rcx, [shader_prog]
    lea  rdx, [u_light_col_name]
    lea  r8,  [light_color]
    call shader_set_vec3

    lea  rcx, [shader_prog]
    lea  rdx, [u_ambient_name]
    movss xmm2, [ambient_level]
    call shader_set_float

.no_shader:
    ; ---- Cube mesh ----
    lea  rcx, [cube_mesh]
    call mesh_create_cube

    ; ---- GL state ----
    mov  ecx, GL_DEPTH_TEST
    call glEnable
    mov  ecx, GL_CULL_FACE
    call glEnable
    mov  ecx, GL_BACK
    call glCullFace
    mov  ecx, GL_CCW
    call glFrontFace

    add  rsp, 0x20
    pop  rbx
    ret

; ============================================================
renderer_draw:
    push rbx
    push r12
    sub  rsp, 0x28

    ; ---- No shader? clear & present ----
    lea  rax, [shader_prog]
    cmp  dword [rax+SP_ID], 0
    jne  .do_draw

    movss xmm0, [bg_rgb]
    movss xmm1, [bg_rgb]
    movss xmm2, [bg_rgb]
    movss xmm3, [f_1_0]
    call glClearColor
    mov  ecx, GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT
    call glClear
    jmp  .present

.do_draw:
    ; ---- Hot reload ----
    lea  rcx, [shader_prog]
    call shader_program_hot_reload
    test eax, eax
    jz   .no_reload
    lea  rcx, [shader_prog]
    call shader_program_use

    ; After reload, re-set light uniforms (they were lost with the old program)
    lea  rcx, [shader_prog]
    lea  rdx, [u_light_dir_name]
    lea  r8,  [light_dir]
    call shader_set_vec3

    lea  rcx, [shader_prog]
    lea  rdx, [u_light_col_name]
    lea  r8,  [light_color]
    call shader_set_vec3

    lea  rcx, [shader_prog]
    lea  rdx, [u_ambient_name]
    movss xmm2, [ambient_level]
    call shader_set_float

.no_reload:

    ; ---- Clear ----
    movss xmm0, [bg_rgb]
    movss xmm1, [bg_rgb]
    movss xmm2, [bg_rgb]
    movss xmm3, [f_1_0]
    call glClearColor
    mov  ecx, GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT
    call glClear

    ; ---- Proj, View, PV = Proj * View ----
    lea  rcx, [mat_proj]
    call camera_get_proj

    lea  rcx, [mat_view]
    call camera_get_view

    lea  rcx, [mat_pv]
    lea  rdx, [mat_proj]
    lea  r8,  [mat_view]
    call mat4_mul

    ; ---- Iterate instances ----
    lea  rbx, [instances]
    mov  r12d, NUM_INSTANCES

.draw_loop:
    ; mat_tmp = T(pos)
    lea  rcx, [mat_tmp]
    movss xmm0, [rbx+0]
    movss xmm1, [rbx+4]
    movss xmm2, [rbx+8]
    call mat4_make_translate

    ; mat_tmp2 = R(angle_y)
    lea  rcx, [mat_tmp2]
    movss xmm0, [rbx+16]
    call mat4_make_rotate_y

    ; mat_model = T * R
    lea  rcx, [mat_model]
    lea  rdx, [mat_tmp]
    lea  r8,  [mat_tmp2]
    call mat4_mul

    ; mat_mvp = PV * mat_model
    lea  rcx, [mat_mvp]
    lea  rdx, [mat_pv]
    lea  r8,  [mat_model]
    call mat4_mul

    ; ---- Set uniforms ----
    lea  rcx, [shader_prog]
    lea  rdx, [u_mvp_name]
    lea  r8,  [mat_mvp]
    call shader_set_mat4

    lea  rcx, [shader_prog]
    lea  rdx, [u_model_name]
    lea  r8,  [mat_model]
    call shader_set_mat4

    ; ---- Draw ----
    lea  rcx, [cube_mesh]
    call mesh_draw

    ; ---- Advance rotation ----
    movss xmm0, [dt_seconds]
    mulss xmm0, [rbx+20]
    addss xmm0, [rbx+16]
    movss [rbx+16], xmm0

    add  rbx, INSTANCE_SIZE
    dec  r12d
    jnz  .draw_loop

.present:
    call win32_swap_buffers
    add  rsp, 0x28
    pop  r12
    pop  rbx
    ret
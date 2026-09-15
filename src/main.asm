; ============================================================
; src/main.asm
; Physics demo: entities fall under gravity, bounce off ground
; ============================================================
BITS 64
default rel

%include "win32.inc"
%include "gl.inc"
%include "math.inc"
%include "input.inc"
%include "shader.inc"
%include "mesh.inc"
%include "texture.inc"
%include "entity.inc"

extern glBindVertexArray
extern glDrawElements
extern glClear
extern glClearColor
extern glEnable
extern glCullFace
extern glFrontFace

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
extern input_is_pressed

extern camera_get_view
extern camera_get_proj
extern camera_get_pos
extern camera_update

extern cam_pos
extern cam_yaw
extern cam_pitch

extern mat4_mul
extern mat4_make_translate
extern mat4_make_rotate_y
extern mat4_make_scale

extern path_join_exe

extern shader_program_init
extern shader_program_hot_reload
extern shader_program_use
extern shader_program_destroy
extern shader_set_mat4
extern shader_set_vec3
extern shader_set_float
extern glGetUniformLocation
extern glUniform1i

extern mesh_create_cube
extern mesh_create_sphere
extern mesh_create_pyramid
extern mesh_draw
extern mesh_destroy

extern texture_create_checkerboard
extern texture_create_from_file
extern texture_bind
extern texture_destroy

extern entity_init
extern entity_spawn_cube
extern entity_spawn_sphere
extern entity_spawn_pyramid
extern entity_destroy_last
extern entity_update_all
extern entities

extern time_init
extern time_dt

extern image_init
extern image_shutdown

extern GetModuleHandleA
extern ShowWindow
extern UpdateWindow
extern PeekMessageA
extern TranslateMessage
extern DispatchMessageA
extern DefWindowProcA
extern PostQuitMessage
extern DestroyWindow
extern MessageBoxA

global WinMain

; ============================================================
section .data
align 16

window_title db "3dre Physics | C/V/B=spawn  Del=remove  WASD+QE/RF=move",0
rel_vs_path  db "shaders\basic.vert",0
rel_fs_path  db "shaders\basic.frag",0
rel_png_a    db "assets\test.png",0

u_mvp_name        db "uMVP",0
u_model_name      db "uModel",0
u_color_name      db "uColor",0
u_albedo_name     db "uAlbedo",0
u_light_dir_name  db "uLightDir",0
u_light_col_name  db "uLightColor",0
u_ambient_name    db "uAmbient",0
u_camera_pos_name db "uCameraPos",0
u_spec_col_name   db "uSpecularColor",0
u_shininess_name  db "uShininess",0

dbg_title       db "3dre Debug",0
dbg_shader_fail db "Shader failed to load.",0

align 16
light_dir        dd 0.4, 0.7, 0.5
light_color      dd 1.0, 1.0, 1.0
ambient_level    dd 0.25
spec_color       dd 1.0, 1.0, 1.0
shininess        dd 64.0

; ---- Ground settings ----
ground_pos_y:    dd -4.05
ground_scale_x:  dd 20.0
ground_scale_y:  dd 0.1
ground_scale_z:  dd 20.0
ground_color:    dd 0.30, 0.32, 0.36

; ---- Spawn velocity: forward * this ----
spawn_forward_speed: dd 3.0

; ---- Initial spawn: entities start above ground and fall ----
align 16
spawn_list:
    dd E_TYPE_CUBE,    0,   -3.0,  2.0, -1.0,   0.8,   1.0, 1.0, 1.0
    dd E_TYPE_CUBE,    1,    3.0,  3.0, -1.0,   0.6,   0.3, 1.0, 0.3
    dd E_TYPE_PYRAMID, 0,   -3.0,  4.0,  1.0,   0.7,   1.0, 1.0, 1.0
    dd E_TYPE_PYRAMID, 1,    3.0,  2.5,  1.0,   0.5,   1.0, 1.0, 0.3
    dd E_TYPE_SPHERE,  0,   -4.0,  5.0,  0.0,   0.9,   1.0, 1.0, 1.0
    dd E_TYPE_SPHERE,  1,    0.0,  6.0,  0.0,   1.2,   0.9, 0.9, 0.95
    dd E_TYPE_SPHERE,  0,    4.0,  3.5,  0.0,   0.9,   1.0, 1.0, 1.0
    dd E_TYPE_SPHERE,  1,    0.0,  4.5,  0.0,   1.2,   0.5, 0.7, 1.0

NUM_SPAWNS equ 8
SPAWN_SIZE equ 36

align 16
f_1_0:      dd 1.0
f_4_0:      dd 4.0

align 16
bg_rgb:     dd 0.12

; ============================================================
section .bss

hInstance       resq 1
hwnd            resq 1
msg             resb 48

abs_vs_path     resb 260
abs_fs_path     resb 260
abs_png_a       resb 260

shader_prog     resb SP_SIZE
cube_mesh       resb MESH_SIZE
sphere_mesh     resb MESH_SIZE
pyramid_mesh    resb MESH_SIZE

tex_slot0       resb TEXTURE_SIZE
tex_slot1       resb TEXTURE_SIZE

mat_proj        resb 64
mat_view        resb 64
mat_pv          resb 64
mat_tmp         resb 64
mat_tmp2        resb 64
mat_model       resb 64
mat_mvp         resb 64

dt_seconds      resd 1
spawn_fwd       resd 3
spawn_pos       resd 3

; ============================================================
section .text

; ============================================================
set_light_uniforms:
    sub  rsp, 0x28

    mov  eax, [shader_prog + SP_ID]
    test eax, eax
    jz   .done

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

    lea  rcx, [shader_prog]
    lea  rdx, [u_spec_col_name]
    lea  r8,  [spec_color]
    call shader_set_vec3

    lea  rcx, [shader_prog]
    lea  rdx, [u_shininess_name]
    movss xmm2, [shininess]
    call shader_set_float

    mov  ecx, [shader_prog + SP_ID]
    lea  rdx, [u_albedo_name]
    call qword [glGetUniformLocation]
    cmp  eax, -1
    je   .done
    mov  ecx, eax
    xor  edx, edx
    call qword [glUniform1i]

.done:
    add  rsp, 0x28
    ret

; ============================================================
; spawn_at_camera(type)  — spawn 4 units ahead with forward velocity
;   ecx = E_TYPE_*
; ============================================================
spawn_at_camera:
    push rbx
    push r12
    sub  rsp, 0x28

    mov  r12d, ecx                 ; type

    ; ---- compute forward from cam_yaw, cam_pitch ----
    fld  dword [cam_yaw]
    fsincos
    fstp dword [rsp+0x00]          ; cos_yaw
    fstp dword [rsp+0x04]          ; sin_yaw

    fld  dword [cam_pitch]
    fsincos
    fstp dword [rsp+0x08]          ; cos_pitch
    fstp dword [rsp+0x0C]          ; sin_pitch

    ; fwd.x = sin_yaw * cos_pitch
    movss xmm0, [rsp+0x04]
    mulss xmm0, [rsp+0x08]
    movss [spawn_fwd + 0], xmm0

    ; fwd.y = sin_pitch
    movss xmm0, [rsp+0x0C]
    movss [spawn_fwd + 4], xmm0

    ; fwd.z = -cos_yaw * cos_pitch
    movss xmm0, [rsp+0x00]
    mulss xmm0, [rsp+0x08]
    xorps xmm1, xmm1
    subss xmm1, xmm0
    movss [spawn_fwd + 8], xmm1

    ; ---- pos = cam_pos + fwd * 4 ----
    movss xmm7, [f_4_0]

    movss xmm0, [spawn_fwd + 0]
    mulss xmm0, xmm7
    addss xmm0, [cam_pos + 0]
    movss [spawn_pos + 0], xmm0

    movss xmm0, [spawn_fwd + 4]
    mulss xmm0, xmm7
    addss xmm0, [cam_pos + 4]
    movss [spawn_pos + 4], xmm0

    movss xmm0, [spawn_fwd + 8]
    mulss xmm0, xmm7
    addss xmm0, [cam_pos + 8]
    movss [spawn_pos + 8], xmm0

    ; ---- velocity = fwd * spawn_forward_speed ----
    movss xmm7, [spawn_forward_speed]

    movss xmm7, [spawn_fwd + 0]
    mulss xmm7, [spawn_forward_speed]
    ; xmm7 = vel.x

    movss xmm8, [spawn_fwd + 4]
    mulss xmm8, [spawn_forward_speed]
    ; xmm8 = vel.y

    movss xmm9, [spawn_fwd + 8]
    mulss xmm9, [spawn_forward_speed]
    ; xmm9 = vel.z

    ; ---- spawn args ----
    movss xmm0, [spawn_pos + 0]
    movss xmm1, [spawn_pos + 4]
    movss xmm2, [spawn_pos + 8]

    mov  eax, 0x3F800000           ; 1.0f
    movd xmm3, eax                 ; rot_speed
    movd xmm4, eax                 ; r
    movd xmm5, eax                 ; g
    movd xmm6, eax                 ; b
    ; xmm7..xmm9 = velocity (already set)

    mov  edx, [tex_slot0 + TEX_ID]

    cmp  r12d, E_TYPE_CUBE
    je   .cube
    cmp  r12d, E_TYPE_SPHERE
    je   .sphere
    cmp  r12d, E_TYPE_PYRAMID
    je   .pyramid
    jmp  .done

.cube:
    call entity_spawn_cube
    jmp  .done
.sphere:
    call entity_spawn_sphere
    jmp  .done
.pyramid:
    call entity_spawn_pyramid

.done:
    add  rsp, 0x28
    pop  r12
    pop  rbx
    ret

; ============================================================
handle_entity_input:
    sub  rsp, 0x28

    mov  ecx, VK_C
    call input_is_pressed
    test eax, eax
    jz   .no_c
    mov  ecx, E_TYPE_CUBE
    call spawn_at_camera
.no_c:

    mov  ecx, VK_V
    call input_is_pressed
    test eax, eax
    jz   .no_v
    mov  ecx, E_TYPE_SPHERE
    call spawn_at_camera
.no_v:

    mov  ecx, VK_B
    call input_is_pressed
    test eax, eax
    jz   .no_b
    mov  ecx, E_TYPE_PYRAMID
    call spawn_at_camera
.no_b:

    mov  ecx, VK_DELETE
    call input_is_pressed
    test eax, eax
    jz   .done
    call entity_destroy_last

.done:
    add  rsp, 0x28
    ret

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
    call time_init
    call image_init
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
    call handle_entity_input
    movss xmm0, [dt_seconds]
    call camera_update
    movss xmm0, [dt_seconds]
    call entity_update_all
    call renderer_draw
    call input_end_frame
    jmp  .loop

.exit:
    call image_shutdown
    lea  rcx, [tex_slot1]
    call texture_destroy
    lea  rcx, [tex_slot0]
    call texture_destroy
    lea  rcx, [pyramid_mesh]
    call mesh_destroy
    lea  rcx, [sphere_mesh]
    call mesh_destroy
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
    call time_dt
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
    push r12
    sub  rsp, 0x28

    lea  rcx, [rel_vs_path]
    lea  rdx, [abs_vs_path]
    mov  r8d, 260
    call path_join_exe

    lea  rcx, [rel_fs_path]
    lea  rdx, [abs_fs_path]
    mov  r8d, 260
    call path_join_exe

    lea  rcx, [shader_prog]
    lea  rdx, [abs_vs_path]
    lea  r8,  [abs_fs_path]
    call shader_program_init
    test eax, eax
    jz   .no_shader

    lea  rcx, [shader_prog]
    call shader_program_use
    call set_light_uniforms

.no_shader:
    lea  rcx, [cube_mesh]
    call mesh_create_cube

    lea  rcx, [sphere_mesh]
    mov  edx, 32
    mov  r8d, 24
    call mesh_create_sphere

    lea  rcx, [pyramid_mesh]
    call mesh_create_pyramid

    lea  rcx, [rel_png_a]
    lea  rdx, [abs_png_a]
    mov  r8d, 260
    call path_join_exe

    lea  rcx, [tex_slot0]
    lea  rdx, [abs_png_a]
    call texture_create_from_file
    test eax, eax
    jnz  .png_ok

    lea  rcx, [tex_slot0]
    mov  edx, 16
    mov  r8d, 8
    call texture_create_checkerboard

.png_ok:
    lea  rcx, [tex_slot1]
    mov  edx, 32
    mov  r8d, 4
    call texture_create_checkerboard

    call entity_init

    ; ---- initial spawn: entities above ground, velocity = 0 ----
    lea  rbx, [spawn_list]
    mov  r12d, NUM_SPAWNS

.spawn_loop:
    mov  eax, [rbx + 0]

    mov  ecx, [rbx + 4]
    test ecx, ecx
    jnz  .use_slot1
    mov  edx, [tex_slot0 + TEX_ID]
    jmp  .tex_picked
.use_slot1:
    mov  edx, [tex_slot1 + TEX_ID]
.tex_picked:

    movss xmm0, [rbx + 8]
    movss xmm1, [rbx + 12]
    movss xmm2, [rbx + 16]
    movss xmm3, [rbx + 20]
    movss xmm4, [rbx + 24]
    movss xmm5, [rbx + 28]
    movss xmm6, [rbx + 32]

    ; velocity = 0
    xorps xmm7, xmm7
    xorps xmm8, xmm8
    xorps xmm9, xmm9

    cmp  eax, E_TYPE_CUBE
    je   .spawn_cube
    cmp  eax, E_TYPE_SPHERE
    je   .spawn_sphere
    cmp  eax, E_TYPE_PYRAMID
    je   .spawn_pyramid
    jmp  .spawn_next

.spawn_cube:
    call entity_spawn_cube
    jmp  .spawn_next
.spawn_sphere:
    call entity_spawn_sphere
    jmp  .spawn_next
.spawn_pyramid:
    call entity_spawn_pyramid

.spawn_next:
    add  rbx, SPAWN_SIZE
    dec  r12d
    jnz  .spawn_loop

    mov  ecx, GL_DEPTH_TEST
    call glEnable
    mov  ecx, GL_CULL_FACE
    call glEnable
    mov  ecx, GL_BACK
    call glCullFace
    mov  ecx, GL_CCW
    call glFrontFace

    add  rsp, 0x28
    pop  r12
    pop  rbx
    ret

; ============================================================
renderer_draw:
    push rbx
    push r12
    sub  rsp, 0x28

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
    lea  rcx, [shader_prog]
    call shader_program_hot_reload
    test eax, eax
    jz   .no_reload
    lea  rcx, [shader_prog]
    call shader_program_use
    call set_light_uniforms
.no_reload:

    movss xmm0, [bg_rgb]
    movss xmm1, [bg_rgb]
    movss xmm2, [bg_rgb]
    movss xmm3, [f_1_0]
    call glClearColor
    mov  ecx, GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT
    call glClear

    call camera_get_pos
    mov  r8, rcx
    lea  rcx, [shader_prog]
    lea  rdx, [u_camera_pos_name]
    call shader_set_vec3

    lea  rcx, [mat_proj]
    call camera_get_proj

    lea  rcx, [mat_view]
    call camera_get_view

    lea  rcx, [mat_pv]
    lea  rdx, [mat_proj]
    lea  r8,  [mat_view]
    call mat4_mul

    ; ============================================
    ; Draw ground (scaled cube at y = -4.05)
    ; ============================================
    ; mat_tmp = T(0, ground_pos_y, 0)
    lea  rcx, [mat_tmp]
    xorps xmm0, xmm0
    movss xmm1, [ground_pos_y]
    xorps xmm2, xmm2
    call mat4_make_translate

    ; mat_tmp2 = S(20, 0.1, 20)
    lea  rcx, [mat_tmp2]
    movss xmm0, [ground_scale_x]
    movss xmm1, [ground_scale_y]
    movss xmm2, [ground_scale_z]
    call mat4_make_scale

    ; mat_model = T * S
    lea  rcx, [mat_model]
    lea  rdx, [mat_tmp]
    lea  r8,  [mat_tmp2]
    call mat4_mul

    ; mat_mvp = pv * model
    lea  rcx, [mat_mvp]
    lea  rdx, [mat_pv]
    lea  r8,  [mat_model]
    call mat4_mul

    ; bind slot1 texture
    mov  eax, [tex_slot1 + TEX_ID]
    mov  [rsp+0x10], eax
    mov  dword [rsp+0x14], 0
    mov  dword [rsp+0x18], 0
    mov  dword [rsp+0x1C], 0
    lea  rcx, [rsp+0x10]
    mov  edx, GL_TEXTURE0
    call texture_bind

    lea  rcx, [shader_prog]
    lea  rdx, [u_mvp_name]
    lea  r8,  [mat_mvp]
    call shader_set_mat4

    lea  rcx, [shader_prog]
    lea  rdx, [u_model_name]
    lea  r8,  [mat_model]
    call shader_set_mat4

    lea  rcx, [shader_prog]
    lea  rdx, [u_color_name]
    lea  r8,  [ground_color]
    call shader_set_vec3

    lea  rcx, [cube_mesh]
    call mesh_draw

    ; ============================================
    ; Draw entities
    ; ============================================
    lea  rbx, [entities]
    mov  r12d, MAX_ENTITIES

.entity_loop:
    cmp  dword [rbx + E_TYPE], E_TYPE_EMPTY
    je   .entity_next

    lea  rcx, [mat_tmp]
    movss xmm0, [rbx + E_POS + 0]
    movss xmm1, [rbx + E_POS + 4]
    movss xmm2, [rbx + E_POS + 8]
    call mat4_make_translate

    lea  rcx, [mat_tmp2]
    movss xmm0, [rbx + E_ROT_Y]
    call mat4_make_rotate_y

    lea  rcx, [mat_model]
    lea  rdx, [mat_tmp]
    lea  r8,  [mat_tmp2]
    call mat4_mul

    lea  rcx, [mat_mvp]
    lea  rdx, [mat_pv]
    lea  r8,  [mat_model]
    call mat4_mul

    mov  eax, [rbx + E_TEXTURE]
    test eax, eax
    jz   .no_tex
    mov  [rsp+0x10], eax
    mov  dword [rsp+0x14], 0
    mov  dword [rsp+0x18], 0
    mov  dword [rsp+0x1C], 0
    lea  rcx, [rsp+0x10]
    mov  edx, GL_TEXTURE0
    call texture_bind
.no_tex:

    lea  rcx, [shader_prog]
    lea  rdx, [u_mvp_name]
    lea  r8,  [mat_mvp]
    call shader_set_mat4

    lea  rcx, [shader_prog]
    lea  rdx, [u_model_name]
    lea  r8,  [mat_model]
    call shader_set_mat4

    lea  rcx, [shader_prog]
    lea  rdx, [u_color_name]
    lea  r8,  [rbx + E_COLOR]
    call shader_set_vec3

    mov  eax, [rbx + E_TYPE]
    cmp  eax, E_TYPE_CUBE
    je   .draw_cube
    cmp  eax, E_TYPE_SPHERE
    je   .draw_sphere
    cmp  eax, E_TYPE_PYRAMID
    je   .draw_pyramid
    jmp  .entity_next

.draw_cube:
    lea  rcx, [cube_mesh]
    call mesh_draw
    jmp  .entity_next
.draw_sphere:
    lea  rcx, [sphere_mesh]
    call mesh_draw
    jmp  .entity_next
.draw_pyramid:
    lea  rcx, [pyramid_mesh]
    call mesh_draw

.entity_next:
    add  rbx, ENTITY_SIZE
    dec  r12d
    jnz  .entity_loop

.present:
    call win32_swap_buffers
    add  rsp, 0x28
    pop  r12
    pop  rbx
    ret
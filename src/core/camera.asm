; ============================================================
; src/core/camera.asm
; FPS camera with yaw/pitch, WASD movement, mouse look
; ============================================================
BITS 64
default rel

%include "math.inc"
%include "input.inc"

section .data
align 16
cam_pos:        dd 0.0, 0.0, 5.0, 0.0
cam_yaw:        dd 0.0
cam_pitch:      dd 0.0
cam_speed:      dd 1.5
cam_rot_speed:  dd 0.9
mouse_sensitivity: dd 0.003

cam_fov:        dd 1.0471975511965976
cam_aspect:     dd 1.3333333333333333
cam_near:       dd 0.1
cam_far:        dd 200.0

align 16
sign_flip:      dd 0x80000000, 0x80000000, 0x80000000, 0x80000000
f_neg_half_pi:  dd -1.5707963267948966
f_half_pi:      dd  1.5707963267948966

section .bss
align 16
tmp_cam_m1:     resb 64
tmp_cam_m2:     resb 64
tmp_cam_m3:     resb 64

section .text
global camera_get_view
global camera_get_proj
global camera_update
global camera_get_pos
global camera_get_forward

global cam_pos
global cam_yaw
global cam_pitch
global cam_fov
global cam_aspect
global cam_near
global cam_far

extern mat4_mul
extern mat4_make_rotate_x
extern mat4_make_rotate_y
extern mat4_make_translate
extern mat4_make_perspective
extern input_is_down
extern mouse_delta_x
extern mouse_delta_y

; ============================================================
camera_get_view:
    push rbx
    sub  rsp, 0x20
    mov  rbx, rcx

    movss xmm0, [cam_pos]
    xorps xmm0, [sign_flip]
    movss xmm1, [cam_pos+4]
    xorps xmm1, [sign_flip]
    movss xmm2, [cam_pos+8]
    xorps xmm2, [sign_flip]
    lea  rcx, [tmp_cam_m1]
    call mat4_make_translate

    movss xmm0, [cam_yaw]
    xorps xmm0, [sign_flip]
    lea  rcx, [tmp_cam_m2]
    call mat4_make_rotate_y

    lea  rcx, [tmp_cam_m3]
    lea  rdx, [tmp_cam_m2]
    lea  r8,  [tmp_cam_m1]
    call mat4_mul

    movss xmm0, [cam_pitch]
    xorps xmm0, [sign_flip]
    lea  rcx, [tmp_cam_m2]
    call mat4_make_rotate_x

    mov  rcx, rbx
    lea  rdx, [tmp_cam_m2]
    lea  r8,  [tmp_cam_m3]
    call mat4_mul

    add  rsp, 0x20
    pop  rbx
    ret

; ============================================================
camera_get_proj:
    sub  rsp, 0x28
    movss xmm0, [cam_fov]
    movss xmm1, [cam_aspect]
    movss xmm2, [cam_near]
    movss xmm3, [cam_far]
    call mat4_make_perspective
    add  rsp, 0x28
    ret

; ============================================================
camera_get_pos:
    lea  rcx, [cam_pos]
    ret

; ============================================================
; camera_get_forward(float* out_xyz)  ; rcx = pointer to 3 floats
;   forward = (sin(yaw)*cos(pitch), sin(pitch), -cos(yaw)*cos(pitch))
; ============================================================
camera_get_forward:
    sub  rsp, 0x38

    mov  [rsp], rcx                ; save out pointer

    ; cos/sin of yaw
    fld  dword [cam_yaw]
    fsincos
    fstp dword [rsp+4]             ; cos_yaw
    fstp dword [rsp+8]             ; sin_yaw

    ; cos/sin of pitch
    fld  dword [cam_pitch]
    fsincos
    fstp dword [rsp+12]            ; cos_pitch
    fstp dword [rsp+16]            ; sin_pitch

    ; x = sin(yaw) * cos(pitch)
    movss xmm0, [rsp+8]
    mulss xmm0, [rsp+12]

    ; y = sin(pitch)
    movss xmm1, [rsp+16]

    ; z = -cos(yaw) * cos(pitch)
    movss xmm2, [rsp+4]
    mulss xmm2, [rsp+12]
    xorps xmm3, xmm3
    subss xmm3, xmm2
    movss xmm2, xmm3

    mov  rax, [rsp]
    movss [rax+0], xmm0
    movss [rax+4], xmm1
    movss [rax+8], xmm2

    add  rsp, 0x38
    ret

; ============================================================
; camera_update(float dt)
; ============================================================
camera_update:
    push rbx
    push rsi
    sub  rsp, 0x28

    movss [rsp], xmm0

    ; ---- Mouse look ----
    cvtsi2ss xmm0, dword [mouse_delta_x]
    mulss xmm0, [mouse_sensitivity]
    movss xmm1, [cam_yaw]
    subss xmm1, xmm0
    movss [cam_yaw], xmm1

    cvtsi2ss xmm0, dword [mouse_delta_y]
    mulss xmm0, [mouse_sensitivity]
    movss xmm1, [cam_pitch]
    subss xmm1, xmm0
    movss [cam_pitch], xmm1

    ; ---- Rotation speed * dt ----
    movss xmm0, [rsp]
    mulss xmm0, [cam_rot_speed]
    movss [rsp+4], xmm0

    ; ---- Q/E yaw ----
    mov  ecx, VK_Q
    call input_is_down
    test eax, eax
    jz   .no_q
    movss xmm0, [cam_yaw]
    addss xmm0, [rsp+4]
    movss [cam_yaw], xmm0
.no_q:
    mov  ecx, VK_E
    call input_is_down
    test eax, eax
    jz   .no_e
    movss xmm0, [cam_yaw]
    subss xmm0, [rsp+4]
    movss [cam_yaw], xmm0
.no_e:

    ; ---- R/F pitch ----
    mov  ecx, VK_R
    call input_is_down
    test eax, eax
    jz   .no_r
    movss xmm0, [cam_pitch]
    addss xmm0, [rsp+4]
    movss [cam_pitch], xmm0
.no_r:
    mov  ecx, VK_F
    call input_is_down
    test eax, eax
    jz   .no_f
    movss xmm0, [cam_pitch]
    subss xmm0, [rsp+4]
    movss [cam_pitch], xmm0
.no_f:

    ; ---- Clamp pitch ----
    movss xmm0, [cam_pitch]
    movss xmm1, [f_half_pi]
    minss xmm0, xmm1
    movss xmm2, [f_neg_half_pi]
    maxss xmm0, xmm2
    movss [cam_pitch], xmm0

    ; ---- Movement distance: dist = dt * cam_speed ----
    movss xmm0, [rsp]
    mulss xmm0, [cam_speed]
    movss [rsp+8], xmm0

    ; ---- W ----
    mov  ecx, VK_W
    call input_is_down
    test eax, eax
    jz   .no_w
    movss xmm0, [rsp+8]
    call camera_move_forward
.no_w:
    ; ---- S ----
    mov  ecx, VK_S
    call input_is_down
    test eax, eax
    jz   .no_s
    movss xmm0, [rsp+8]
    call camera_move_backward
.no_s:
    ; ---- A ----
    mov  ecx, VK_A
    call input_is_down
    test eax, eax
    jz   .no_a
    movss xmm0, [rsp+8]
    call camera_move_left
.no_a:
    ; ---- D ----
    mov  ecx, VK_D
    call input_is_down
    test eax, eax
    jz   .no_d
    movss xmm0, [rsp+8]
    call camera_move_right
.no_d:

    add  rsp, 0x28
    pop  rsi
    pop  rbx
    ret

; ============================================================
camera_move_forward:
    sub  rsp, 0x18
    movss [rsp+0x10], xmm0

    fld  dword [cam_yaw]
    fsin
    fld  dword [cam_pitch]
    fcos
    fmulp st1, st0
    fmul dword [rsp+0x10]
    fstp dword [rsp]

    fld  dword [cam_pitch]
    fsin
    fmul dword [rsp+0x10]
    fstp dword [rsp+4]

    fld  dword [cam_yaw]
    fcos
    fld  dword [cam_pitch]
    fcos
    fmulp st1, st0
    fchs
    fmul dword [rsp+0x10]
    fstp dword [rsp+8]

    movss xmm0, [cam_pos]
    addss xmm0, [rsp]
    movss [cam_pos], xmm0
    movss xmm0, [cam_pos+4]
    addss xmm0, [rsp+4]
    movss [cam_pos+4], xmm0
    movss xmm0, [cam_pos+8]
    addss xmm0, [rsp+8]
    movss [cam_pos+8], xmm0

    add  rsp, 0x18
    ret

camera_move_backward:
    sub  rsp, 0x18
    movss xmm1, [sign_flip]
    xorps xmm0, xmm1
    movss [rsp+0x10], xmm0

    fld  dword [cam_yaw]
    fsin
    fld  dword [cam_pitch]
    fcos
    fmulp st1, st0
    fmul dword [rsp+0x10]
    fstp dword [rsp]

    fld  dword [cam_pitch]
    fsin
    fmul dword [rsp+0x10]
    fstp dword [rsp+4]

    fld  dword [cam_yaw]
    fcos
    fld  dword [cam_pitch]
    fcos
    fmulp st1, st0
    fchs
    fmul dword [rsp+0x10]
    fstp dword [rsp+8]

    movss xmm0, [cam_pos]
    addss xmm0, [rsp]
    movss [cam_pos], xmm0
    movss xmm0, [cam_pos+4]
    addss xmm0, [rsp+4]
    movss [cam_pos+4], xmm0
    movss xmm0, [cam_pos+8]
    addss xmm0, [rsp+8]
    movss [cam_pos+8], xmm0

    add  rsp, 0x18
    ret

camera_move_left:
    sub  rsp, 0x18
    movss [rsp+0x10], xmm0

    fld  dword [cam_yaw]
    fcos
    fmul dword [rsp+0x10]
    fchs
    fstp dword [rsp]

    mov  dword [rsp+4], 0

    fld  dword [cam_yaw]
    fsin
    fmul dword [rsp+0x10]
    fchs
    fstp dword [rsp+8]

    movss xmm0, [cam_pos]
    addss xmm0, [rsp]
    movss [cam_pos], xmm0
    movss xmm0, [cam_pos+8]
    addss xmm0, [rsp+8]
    movss [cam_pos+8], xmm0

    add  rsp, 0x18
    ret

camera_move_right:
    sub  rsp, 0x18
    movss [rsp+0x10], xmm0

    fld  dword [cam_yaw]
    fcos
    fmul dword [rsp+0x10]
    fstp dword [rsp]

    mov  dword [rsp+4], 0

    fld  dword [cam_yaw]
    fsin
    fmul dword [rsp+0x10]
    fstp dword [rsp+8]

    movss xmm0, [cam_pos]
    addss xmm0, [rsp]
    movss [cam_pos], xmm0
    movss xmm0, [cam_pos+8]
    addss xmm0, [rsp+8]
    movss [cam_pos+8], xmm0

    add  rsp, 0x18
    ret
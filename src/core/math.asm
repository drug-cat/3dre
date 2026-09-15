; ============================================================
; src/core/math.asm
; vec3 / mat4 math with SSE2 + x87 for trig
; Column-major layout (matches OpenGL)
; All memory accesses use movups (no alignment requirement)
; ============================================================
BITS 64
default rel

section .rodata
align 16
c_id_c0:    dd 1.0, 0.0, 0.0, 0.0
c_id_c1:    dd 0.0, 1.0, 0.0, 0.0
c_id_c2:    dd 0.0, 0.0, 1.0, 0.0
c_id_c3:    dd 0.0, 0.0, 0.0, 1.0

c_half:     dd 0.5
c_one:      dd 1.0
c_neg_one:  dd -1.0
c_two:      dd 2.0

section .text

; ============================================================
; void mat4_identity(float* dst)
; ============================================================
global mat4_identity
mat4_identity:
    movaps xmm0, [c_id_c0]
    movaps xmm1, [c_id_c1]
    movaps xmm2, [c_id_c2]
    movaps xmm3, [c_id_c3]
    movups [rcx],    xmm0
    movups [rcx+16], xmm1
    movups [rcx+32], xmm2
    movups [rcx+48], xmm3
    ret

; ============================================================
; void mat4_mul(float* dst, const float* a, const float* b)
;   dst = a * b
; ============================================================
global mat4_mul
mat4_mul:
    movups xmm0, [rdx]
    movups xmm1, [rdx+16]
    movups xmm2, [rdx+32]
    movups xmm3, [rdx+48]

    ; ---- column 0 of b ----
    movups xmm4, [r8]
    movaps xmm5, xmm4
    shufps xmm4, xmm4, 0x00
    mulps  xmm4, xmm0
    shufps xmm5, xmm5, 0x55
    mulps  xmm5, xmm1
    addps  xmm4, xmm5
    movups xmm5, [r8]
    shufps xmm5, xmm5, 0xAA
    mulps  xmm5, xmm2
    addps  xmm4, xmm5
    movups xmm5, [r8]
    shufps xmm5, xmm5, 0xFF
    mulps  xmm5, xmm3
    addps  xmm4, xmm5
    movups [rcx], xmm4

    ; ---- column 1 of b ----
    movups xmm4, [r8+16]
    movaps xmm5, xmm4
    shufps xmm4, xmm4, 0x00
    mulps  xmm4, xmm0
    shufps xmm5, xmm5, 0x55
    mulps  xmm5, xmm1
    addps  xmm4, xmm5
    movups xmm5, [r8+16]
    shufps xmm5, xmm5, 0xAA
    mulps  xmm5, xmm2
    addps  xmm4, xmm5
    movups xmm5, [r8+16]
    shufps xmm5, xmm5, 0xFF
    mulps  xmm5, xmm3
    addps  xmm4, xmm5
    movups [rcx+16], xmm4

    ; ---- column 2 of b ----
    movups xmm4, [r8+32]
    movaps xmm5, xmm4
    shufps xmm4, xmm4, 0x00
    mulps  xmm4, xmm0
    shufps xmm5, xmm5, 0x55
    mulps  xmm5, xmm1
    addps  xmm4, xmm5
    movups xmm5, [r8+32]
    shufps xmm5, xmm5, 0xAA
    mulps  xmm5, xmm2
    addps  xmm4, xmm5
    movups xmm5, [r8+32]
    shufps xmm5, xmm5, 0xFF
    mulps  xmm5, xmm3
    addps  xmm4, xmm5
    movups [rcx+32], xmm4

    ; ---- column 3 of b ----
    movups xmm4, [r8+48]
    movaps xmm5, xmm4
    shufps xmm4, xmm4, 0x00
    mulps  xmm4, xmm0
    shufps xmm5, xmm5, 0x55
    mulps  xmm5, xmm1
    addps  xmm4, xmm5
    movups xmm5, [r8+48]
    shufps xmm5, xmm5, 0xAA
    mulps  xmm5, xmm2
    addps  xmm4, xmm5
    movups xmm5, [r8+48]
    shufps xmm5, xmm5, 0xFF
    mulps  xmm5, xmm3
    addps  xmm4, xmm5
    movups [rcx+48], xmm4

    ret

; ============================================================
; void mat4_make_translate(float* dst, float x, float y, float z)
;   xmm0 = x, xmm1 = y, xmm2 = z
; ============================================================
global mat4_make_translate
mat4_make_translate:
    movaps xmm3, [c_id_c0]
    movaps xmm4, [c_id_c1]
    movaps xmm5, [c_id_c2]
    movups [rcx],    xmm3
    movups [rcx+16], xmm4
    movups [rcx+32], xmm5
    movss  [rcx+48], xmm0
    movss  [rcx+52], xmm1
    movss  [rcx+56], xmm2
    movss  xmm6, [c_one]
    movss  [rcx+60], xmm6
    ret

; ============================================================
; void mat4_make_scale(float* dst, float sx, float sy, float sz)
; ============================================================
global mat4_make_scale
mat4_make_scale:
    xorps xmm3, xmm3
    movss [rcx],    xmm0
    movss [rcx+4],  xmm3
    movss [rcx+8],  xmm3
    movss [rcx+12], xmm3

    movss [rcx+16], xmm3
    movss [rcx+20], xmm1
    movss [rcx+24], xmm3
    movss [rcx+28], xmm3

    movss [rcx+32], xmm3
    movss [rcx+36], xmm3
    movss [rcx+40], xmm2
    movss [rcx+44], xmm3

    movss [rcx+48], xmm3
    movss [rcx+52], xmm3
    movss [rcx+56], xmm3
    movss xmm4, [c_one]
    movss [rcx+60], xmm4
    ret

; ============================================================
; void mat4_make_rotate_x(float* dst, float angle_rad)
; ============================================================
global mat4_make_rotate_x
mat4_make_rotate_x:
    sub  rsp, 0x18
    movss [rsp], xmm0

    fld  dword [rsp]
    fsincos
    fstp dword [rsp+4]
    fstp dword [rsp+8]

    movss xmm1, [rsp+4]            ; c
    movss xmm2, [rsp+8]            ; s
    xorps xmm3, xmm3
    movss xmm6, [c_one]

    ; col0: (1, 0, 0, 0)
    movss [rcx],    xmm6
    movss [rcx+4],  xmm3
    movss [rcx+8],  xmm3
    movss [rcx+12], xmm3

    ; col1: (0, c, s, 0)
    movss [rcx+16], xmm3
    movss [rcx+20], xmm1
    movss [rcx+24], xmm2
    movss [rcx+28], xmm3

    ; col2: (0, -s, c, 0)
    movss [rcx+32], xmm3
    movss xmm5, xmm2
    xorps xmm7, xmm7
    subss xmm7, xmm5
    movss [rcx+36], xmm7
    movss [rcx+40], xmm1
    movss [rcx+44], xmm3

    ; col3: (0, 0, 0, 1)
    movss [rcx+48], xmm3
    movss [rcx+52], xmm3
    movss [rcx+56], xmm3
    movss [rcx+60], xmm6

    add  rsp, 0x18
    ret

; ============================================================
; void mat4_make_rotate_y(float* dst, float angle_rad)
; ============================================================
global mat4_make_rotate_y
mat4_make_rotate_y:
    sub  rsp, 0x18
    movss [rsp], xmm0

    fld  dword [rsp]
    fsincos
    fstp dword [rsp+4]
    fstp dword [rsp+8]

    movss xmm1, [rsp+4]            ; c
    movss xmm2, [rsp+8]            ; s
    xorps xmm3, xmm3
    movss xmm6, [c_one]

    ; col0: (c, 0, -s, 0)
    movss [rcx],    xmm1
    movss [rcx+4],  xmm3
    movss xmm4, xmm2
    xorps xmm5, xmm5
    subss xmm5, xmm4
    movss [rcx+8],  xmm5
    movss [rcx+12], xmm3

    ; col1: (0, 1, 0, 0)
    movss [rcx+16], xmm3
    movss [rcx+20], xmm6
    movss [rcx+24], xmm3
    movss [rcx+28], xmm3

    ; col2: (s, 0, c, 0)
    movss [rcx+32], xmm2
    movss [rcx+36], xmm3
    movss [rcx+40], xmm1
    movss [rcx+44], xmm3

    ; col3: (0, 0, 0, 1)
    movss [rcx+48], xmm3
    movss [rcx+52], xmm3
    movss [rcx+56], xmm3
    movss [rcx+60], xmm6

    add  rsp, 0x18
    ret

; ============================================================
; void mat4_make_rotate_z(float* dst, float angle_rad)
; ============================================================
global mat4_make_rotate_z
mat4_make_rotate_z:
    sub  rsp, 0x18
    movss [rsp], xmm0

    fld  dword [rsp]
    fsincos
    fstp dword [rsp+4]             ; c
    fstp dword [rsp+8]             ; s

    movss xmm1, [rsp+4]            ; c
    movss xmm2, [rsp+8]            ; s
    xorps xmm3, xmm3
    movss xmm6, [c_one]

    ; col0: (c, s, 0, 0)
    movss [rcx+0],  xmm1
    movss [rcx+4],  xmm2
    movss [rcx+8],  xmm3
    movss [rcx+12], xmm3

    ; col1: (-s, c, 0, 0)
    movss xmm7, xmm2
    xorps xmm5, xmm5
    subss xmm5, xmm7
    movss [rcx+16], xmm5
    movss [rcx+20], xmm1
    movss [rcx+24], xmm3
    movss [rcx+28], xmm3

    ; col2: (0, 0, 1, 0)
    movss [rcx+32], xmm3
    movss [rcx+36], xmm3
    movss [rcx+40], xmm6
    movss [rcx+44], xmm3

    ; col3: (0, 0, 0, 1)
    movss [rcx+48], xmm3
    movss [rcx+52], xmm3
    movss [rcx+56], xmm3
    movss [rcx+60], xmm6

    add  rsp, 0x18
    ret

; ============================================================
; void mat4_make_perspective(float* dst, float fovy_rad,
;                            float aspect, float near, float far)
; ============================================================
global mat4_make_perspective
mat4_make_perspective:
    sub  rsp, 0x28

    movss xmm4, xmm0
    mulss xmm4, [c_half]
    movss [rsp], xmm4

    fld  dword [rsp]
    fsincos
    fstp dword [rsp+4]
    fstp dword [rsp+8]
    movss xmm5, [rsp+4]
    divss xmm5, [rsp+8]
    movss [rsp+12], xmm5

    xorps xmm6, xmm6
    movss xmm5, [rsp+12]

    ; col0: (f/aspect, 0, 0, 0)
    movss xmm7, xmm5
    divss xmm7, xmm1
    movss [rcx],    xmm7
    movss [rcx+4],  xmm6
    movss [rcx+8],  xmm6
    movss [rcx+12], xmm6

    ; col1: (0, f, 0, 0)
    movss [rcx+16], xmm6
    movss [rcx+20], xmm5
    movss [rcx+24], xmm6
    movss [rcx+28], xmm6

    ; col2: (0, 0, (far+near)/(near-far), -1)
    movss [rcx+32], xmm6
    movss [rcx+36], xmm6
    movss xmm7, xmm3
    addss xmm7, xmm2
    movss xmm8, xmm2
    subss xmm8, xmm3
    divss xmm7, xmm8
    movss [rcx+40], xmm7
    movss xmm9, [c_neg_one]
    movss [rcx+44], xmm9

    ; col3: (0, 0, 2*far*near/(near-far), 0)
    movss [rcx+48], xmm6
    movss [rcx+52], xmm6
    movss xmm7, xmm3
    mulss xmm7, xmm2
    addss xmm7, xmm7
    divss xmm7, xmm8
    movss [rcx+56], xmm7
    movss [rcx+60], xmm6

    add  rsp, 0x28
    ret

; ============================================================
; void mat4_make_ortho(float* dst,
;                      float left,  float right,
;                      float bottom, float top,
;                      float near,  float far)
;   xmm0..xmm5 = left, right, bottom, top, near, far
; ============================================================
global mat4_make_ortho
mat4_make_ortho:
    sub  rsp, 0x28

    ; ---- col0 : (2/(r-l), 0, 0, 0) ----
    movss xmm8, xmm1
    subss xmm8, xmm0                ; r - l
    movss xmm9, [c_two]
    divss xmm9, xmm8                ; 2/(r-l)
    movss [rcx+0], xmm9
    mov  dword [rcx+4], 0
    mov  dword [rcx+8], 0
    mov  dword [rcx+12], 0

    ; ---- col1 : (0, 2/(t-b), 0, 0) ----
    movss xmm8, xmm3
    subss xmm8, xmm2                ; t - b
    movss xmm9, [c_two]
    divss xmm9, xmm8
    mov  dword [rcx+16], 0
    movss [rcx+20], xmm9
    mov  dword [rcx+24], 0
    mov  dword [rcx+28], 0

    ; ---- col2 : (0, 0, -2/(f-n), 0) ----
    movss xmm8, xmm5
    subss xmm8, xmm4                ; f - n
    movss xmm9, [c_two]
    xorps xmm10, xmm10
    subss xmm10, xmm9
    divss xmm10, xmm8               ; -2/(f-n)
    mov  dword [rcx+32], 0
    mov  dword [rcx+36], 0
    movss [rcx+40], xmm10
    mov  dword [rcx+44], 0

    ; ---- col3 : (-(r+l)/(r-l), -(t+b)/(t-b), -(f+n)/(f-n), 1) ----
    movss xmm8, xmm1
    addss xmm8, xmm0                ; r + l
    movss xmm9, xmm1
    subss xmm9, xmm0                ; r - l
    xorps xmm10, xmm10
    subss xmm10, xmm8
    divss xmm10, xmm9
    movss [rcx+48], xmm10

    movss xmm8, xmm3
    addss xmm8, xmm2
    movss xmm9, xmm3
    subss xmm9, xmm2
    xorps xmm10, xmm10
    subss xmm10, xmm8
    divss xmm10, xmm9
    movss [rcx+52], xmm10

    movss xmm8, xmm5
    addss xmm8, xmm4
    movss xmm9, xmm5
    subss xmm9, xmm4
    xorps xmm10, xmm10
    subss xmm10, xmm8
    divss xmm10, xmm9
    movss [rcx+56], xmm10

    mov  dword [rcx+60], 0x3F800000

    add  rsp, 0x28
    ret

; ============================================================
; void mat4_make_look_at(float* dst,
;                        float ex,float ey,float ez,
;                        float cx,float cy,float cz,
;                        float ux,float uy,float uz)
;   xmm0..xmm2 = eye
;   xmm3..xmm5 = center
;   xmm6..xmm8 = up
; ============================================================
global mat4_make_look_at
mat4_make_look_at:
    sub  rsp, 0x68

    ; ---- f = normalize(center - eye)  → [rsp+0x00..0x08] ----
    movss xmm9,  xmm3
    subss xmm9,  xmm0
    movss [rsp+0x00], xmm9
    movss xmm9,  xmm4
    subss xmm9,  xmm1
    movss [rsp+0x04], xmm9
    movss xmm9,  xmm5
    subss xmm9,  xmm2
    movss [rsp+0x08], xmm9

    movss xmm10, [rsp+0x00]
    mulss xmm10, xmm10
    movss xmm11, [rsp+0x04]
    mulss xmm11, xmm11
    addss xmm10, xmm11
    movss xmm11, [rsp+0x08]
    mulss xmm11, xmm11
    addss xmm10, xmm11
    sqrtss xmm10, xmm10

    movss xmm11, [rsp+0x00]
    divss xmm11, xmm10
    movss [rsp+0x00], xmm11
    movss xmm11, [rsp+0x04]
    divss xmm11, xmm10
    movss [rsp+0x04], xmm11
    movss xmm11, [rsp+0x08]
    divss xmm11, xmm10
    movss [rsp+0x08], xmm11

    ; ---- s = normalize(cross(f, up))  → [rsp+0x0C..0x14] ----
    movss xmm9, [rsp+0x04]
    mulss xmm9, xmm8
    movss xmm10, [rsp+0x08]
    mulss xmm10, xmm7
    subss xmm9, xmm10
    movss [rsp+0x0C], xmm9

    movss xmm9, [rsp+0x08]
    mulss xmm9, xmm6
    movss xmm10, [rsp+0x00]
    mulss xmm10, xmm8
    subss xmm9, xmm10
    movss [rsp+0x10], xmm9

    movss xmm9, [rsp+0x00]
    mulss xmm9, xmm7
    movss xmm10, [rsp+0x04]
    mulss xmm10, xmm6
    subss xmm9, xmm10
    movss [rsp+0x14], xmm9

    movss xmm10, [rsp+0x0C]
    mulss xmm10, xmm10
    movss xmm11, [rsp+0x10]
    mulss xmm11, xmm11
    addss xmm10, xmm11
    movss xmm11, [rsp+0x14]
    mulss xmm11, xmm11
    addss xmm10, xmm11
    sqrtss xmm10, xmm10

    movss xmm11, [rsp+0x0C]
    divss xmm11, xmm10
    movss [rsp+0x0C], xmm11
    movss xmm11, [rsp+0x10]
    divss xmm11, xmm10
    movss [rsp+0x10], xmm11
    movss xmm11, [rsp+0x14]
    divss xmm11, xmm10
    movss [rsp+0x14], xmm11

    ; ---- u = cross(s, f)  → [rsp+0x18..0x20] ----
    movss xmm9, [rsp+0x10]
    mulss xmm9, [rsp+0x08]
    movss xmm10, [rsp+0x14]
    mulss xmm10, [rsp+0x04]
    subss xmm9, xmm10
    movss [rsp+0x18], xmm9

    movss xmm9, [rsp+0x14]
    mulss xmm9, [rsp+0x00]
    movss xmm10, [rsp+0x0C]
    mulss xmm10, [rsp+0x08]
    subss xmm9, xmm10
    movss [rsp+0x1C], xmm9

    movss xmm9, [rsp+0x0C]
    mulss xmm9, [rsp+0x04]
    movss xmm10, [rsp+0x10]
    mulss xmm10, [rsp+0x00]
    subss xmm9, xmm10
    movss [rsp+0x20], xmm9

    ; ---- write matrix ----
    ; col0 = (s.x, u.x, -f.x, 0)
    movss xmm9, [rsp+0x0C]
    movss [rcx+0], xmm9
    movss xmm9, [rsp+0x18]
    movss [rcx+4], xmm9
    movss xmm9, [rsp+0x00]
    xorps xmm10, xmm10
    subss xmm10, xmm9
    movss [rcx+8], xmm10
    mov  dword [rcx+12], 0

    ; col1 = (s.y, u.y, -f.y, 0)
    movss xmm9, [rsp+0x10]
    movss [rcx+16], xmm9
    movss xmm9, [rsp+0x1C]
    movss [rcx+20], xmm9
    movss xmm9, [rsp+0x04]
    xorps xmm10, xmm10
    subss xmm10, xmm9
    movss [rcx+24], xmm10
    mov  dword [rcx+28], 0

    ; col2 = (s.z, u.z, -f.z, 0)
    movss xmm9, [rsp+0x14]
    movss [rcx+32], xmm9
    movss xmm9, [rsp+0x20]
    movss [rcx+36], xmm9
    movss xmm9, [rsp+0x08]
    xorps xmm10, xmm10
    subss xmm10, xmm9
    movss [rcx+40], xmm10
    mov  dword [rcx+44], 0

    ; col3 = (-s·eye, -u·eye, f·eye, 1)
    movss xmm9, [rsp+0x0C]
    mulss xmm9, xmm0
    movss xmm10, [rsp+0x10]
    mulss xmm10, xmm1
    addss xmm9, xmm10
    movss xmm10, [rsp+0x14]
    mulss xmm10, xmm2
    addss xmm9, xmm10
    xorps xmm11, xmm11
    subss xmm11, xmm9
    movss [rcx+48], xmm11

    movss xmm9, [rsp+0x18]
    mulss xmm9, xmm0
    movss xmm10, [rsp+0x1C]
    mulss xmm10, xmm1
    addss xmm9, xmm10
    movss xmm10, [rsp+0x20]
    mulss xmm10, xmm2
    addss xmm9, xmm10
    xorps xmm11, xmm11
    subss xmm11, xmm9
    movss [rcx+52], xmm11

    movss xmm9, [rsp+0x00]
    mulss xmm9, xmm0
    movss xmm10, [rsp+0x04]
    mulss xmm10, xmm1
    addss xmm9, xmm10
    movss xmm10, [rsp+0x08]
    mulss xmm10, xmm2
    addss xmm9, xmm10
    movss [rcx+56], xmm9

    mov  dword [rcx+60], 0x3F800000

    add  rsp, 0x68
    ret

; ============================================================
; void vec3_dot(const float* a, const float* b) -> xmm0
; ============================================================
global vec3_dot
vec3_dot:
    movss xmm0, [rcx]
    mulss xmm0, [rdx]
    movss xmm1, [rcx+4]
    mulss xmm1, [rdx+4]
    addss xmm0, xmm1
    movss xmm1, [rcx+8]
    mulss xmm1, [rdx+8]
    addss xmm0, xmm1
    ret

; ============================================================
; void vec3_cross(float* out, const float* a, const float* b)
; ============================================================
global vec3_cross
vec3_cross:
    movss xmm0, [rdx+4]
    mulss xmm0, [r8+8]
    movss xmm1, [rdx+8]
    mulss xmm1, [r8+4]
    subss xmm0, xmm1
    movss [rcx], xmm0

    movss xmm0, [rdx+8]
    mulss xmm0, [r8]
    movss xmm1, [rdx]
    mulss xmm1, [r8+8]
    subss xmm0, xmm1
    movss [rcx+4], xmm0

    movss xmm0, [rdx]
    mulss xmm0, [r8+4]
    movss xmm1, [rdx+4]
    mulss xmm1, [r8]
    subss xmm0, xmm1
    movss [rcx+8], xmm0
    ret

; ============================================================
; void vec3_normalize(float* v)   ; in place
; ============================================================
global vec3_normalize
vec3_normalize:
    movss xmm0, [rcx]
    mulss xmm0, xmm0
    movss xmm1, [rcx+4]
    mulss xmm1, xmm1
    addss xmm0, xmm1
    movss xmm1, [rcx+8]
    mulss xmm1, xmm1
    addss xmm0, xmm1

    xorps xmm2, xmm2
    ucomiss xmm0, xmm2
    jbe  .zero
    sqrtss xmm0, xmm0
    movss xmm1, [rcx]
    divss xmm1, xmm0
    movss [rcx], xmm1
    movss xmm1, [rcx+4]
    divss xmm1, xmm0
    movss [rcx+4], xmm1
    movss xmm1, [rcx+8]
    divss xmm1, xmm0
    movss [rcx+8], xmm1
.zero:
    ret
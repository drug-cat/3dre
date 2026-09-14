; ============================================================
; src/render/mesh.asm
; GPU mesh abstraction — cube + procedural UV sphere
; Vertex layout: pos(3) + color(3) + normal(3) = 36 bytes
; ============================================================
BITS 64
default rel

%include "gl.inc"
%include "mesh.inc"

extern glGenVertexArrays
extern glBindVertexArray
extern glDeleteVertexArrays
extern glGenBuffers
extern glBindBuffer
extern glBufferData
extern glDeleteBuffers
extern glVertexAttribPointer
extern glEnableVertexAttribArray
extern glDrawElements

extern LocalAlloc
extern LocalFree

section .data
align 16

pi_const:        dd 3.14159265358979
two_pi_const:    dd 6.28318530717959

; ---- Unit cube: 24 vertices, pos + color + normal ----
cube_vertices:
    ; -Z (red)
    dd -0.5, -0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0
    dd  0.5, -0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0
    dd  0.5,  0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0
    dd -0.5,  0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0
    ; +Z (green)
    dd -0.5, -0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0
    dd  0.5, -0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0
    dd  0.5,  0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0
    dd -0.5,  0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0
    ; -Y (blue)
    dd -0.5, -0.5, -0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0
    dd  0.5, -0.5, -0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0
    dd  0.5, -0.5,  0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0
    dd -0.5, -0.5,  0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0
    ; +Y (yellow)
    dd -0.5,  0.5, -0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0
    dd  0.5,  0.5, -0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0
    dd  0.5,  0.5,  0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0
    dd -0.5,  0.5,  0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0
    ; -X (magenta)
    dd -0.5, -0.5, -0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0
    dd -0.5, -0.5,  0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0
    dd -0.5,  0.5,  0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0
    dd -0.5,  0.5, -0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0
    ; +X (cyan)
    dd  0.5, -0.5, -0.5,   0.0, 1.0, 1.0,    1.0, 0.0, 0.0
    dd  0.5, -0.5,  0.5,   0.0, 1.0, 1.0,    1.0, 0.0, 0.0
    dd  0.5,  0.5,  0.5,   0.0, 1.0, 1.0,    1.0, 0.0, 0.0
    dd  0.5,  0.5, -0.5,   0.0, 1.0, 1.0,    1.0, 0.0, 0.0

align 16
cube_indices:
    dd 0,2,1, 0,3,2
    dd 4,5,6, 4,6,7
    dd 8,9,10, 8,10,11
    dd 12,14,13, 12,15,14
    dd 16,17,18, 16,18,19
    dd 20,22,21, 20,23,22

section .text
global mesh_create_cube
global mesh_create_sphere
global mesh_draw
global mesh_destroy

; ============================================================
; Internal: mesh_upload_attribs(Mesh* m)
;   Assumes VAO bound and VBO bound to GL_ARRAY_BUFFER.
; ============================================================
mesh_upload_attribs:
    push rbx
    sub  rsp, 0x30
    mov  rbx, rcx

    ; aPos
    mov  ecx, MESH_ATTR_POS
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], MESH_VERTEX_SIZE
    mov  qword [rsp+0x28], MESH_ATTR_POS_OFF
    call qword [glVertexAttribPointer]
    mov  ecx, MESH_ATTR_POS
    call qword [glEnableVertexAttribArray]

    ; aColor
    mov  ecx, MESH_ATTR_COLOR
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], MESH_VERTEX_SIZE
    mov  qword [rsp+0x28], MESH_ATTR_COLOR_OFF
    call qword [glVertexAttribPointer]
    mov  ecx, MESH_ATTR_COLOR
    call qword [glEnableVertexAttribArray]

    ; aNormal
    mov  ecx, MESH_ATTR_NORMAL
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], MESH_VERTEX_SIZE
    mov  qword [rsp+0x28], MESH_ATTR_NORMAL_OFF
    call qword [glVertexAttribPointer]
    mov  ecx, MESH_ATTR_NORMAL
    call qword [glEnableVertexAttribArray]

    add  rsp, 0x30
    pop  rbx
    ret

; ============================================================
; mesh_create_cube(Mesh* m) → eax
; ============================================================
mesh_create_cube:
    push rbx
    sub  rsp, 0x30

    mov  rbx, rcx

    pxor xmm0, xmm0
    movdqu [rbx],    xmm0
    movdqu [rbx+16], xmm0

    mov  ecx, 1
    lea  rdx, [rbx + MESH_VAO]
    call qword [glGenVertexArrays]
    mov  ecx, [rbx + MESH_VAO]
    call qword [glBindVertexArray]

    mov  ecx, 1
    lea  rdx, [rbx + MESH_VBO]
    call qword [glGenBuffers]
    mov  ecx, GL_ARRAY_BUFFER
    mov  edx, [rbx + MESH_VBO]
    call qword [glBindBuffer]

    mov  ecx, GL_ARRAY_BUFFER
    mov  edx, 24 * MESH_VERTEX_SIZE
    lea  r8,  [cube_vertices]
    mov  r9d, GL_STATIC_DRAW
    call qword [glBufferData]

    mov  rcx, rbx
    call mesh_upload_attribs

    mov  ecx, 1
    lea  rdx, [rbx + MESH_EBO]
    call qword [glGenBuffers]
    mov  ecx, GL_ELEMENT_ARRAY_BUFFER
    mov  edx, [rbx + MESH_EBO]
    call qword [glBindBuffer]

    mov  ecx, GL_ELEMENT_ARRAY_BUFFER
    mov  edx, 36 * 4
    lea  r8,  [cube_indices]
    mov  r9d, GL_STATIC_DRAW
    call qword [glBufferData]

    mov  dword [rbx + MESH_VERT_COUNT],  24
    mov  dword [rbx + MESH_INDEX_COUNT], 36
    mov  dword [rbx + MESH_STRIDE],      MESH_VERTEX_SIZE

    mov  eax, 1
    add  rsp, 0x30
    pop  rbx
    ret

; ============================================================
; mesh_create_sphere(Mesh* m, u32 slices, u32 stacks) → eax
;   rcx = m, edx = slices (longitude), r8d = stacks (latitude)
;   slices, stacks clamped to [3..64] and [2..64]
; ============================================================
mesh_create_sphere:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 0x100

    ; Stack layout:
    ;   +0x00..0x1F : shadow space (for calls)
    ;   +0x20..0x2F : call stack args
    ;   +0x30+      : locals
    ;
    ; locals:
    ;   [rsp+0x30] : m         (qword)
    ;   [rsp+0x38] : slices    (u32)
    ;   [rsp+0x3C] : stacks    (u32)
    ;   [rsp+0x40] : vert_count(u32)
    ;   [rsp+0x44] : idx_count (u32)
    ;   [rsp+0x48] : vert_buf  (qword)
    ;   [rsp+0x50] : idx_buf   (qword)
    ;   [rsp+0x58] : theta     (f32)
    ;   [rsp+0x5C] : cos_theta (f32)
    ;   [rsp+0x60] : sin_theta (f32)
    ;   [rsp+0x64] : phi       (f32)
    ;   [rsp+0x68] : cos_phi   (f32)
    ;   [rsp+0x6C] : sin_phi   (f32)

    mov  [rsp+0x30], rcx

    ; clamp slices: [3, 64]
    cmp  edx, 3
    jae  .s_ge3
    mov  edx, 3
.s_ge3:
    cmp  edx, 64
    jbe  .s_le64
    mov  edx, 64
.s_le64:
    mov  [rsp+0x38], edx

    ; clamp stacks: [2, 64]
    cmp  r8d, 2
    jae  .st_ge2
    mov  r8d, 2
.st_ge2:
    cmp  r8d, 64
    jbe  .st_le64
    mov  r8d, 64
.st_le64:
    mov  [rsp+0x3C], r8d

    mov  r12d, [rsp+0x38]          ; slices
    mov  r13d, [rsp+0x3C]          ; stacks

    ; vert_count = (stacks + 1) * (slices + 1)
    lea  eax, [r13d + 1]
    lea  ecx, [r12d + 1]
    imul eax, ecx
    mov  [rsp+0x40], eax

    ; idx_count = stacks * slices * 6
    mov  eax, r13d
    imul eax, r12d
    imul eax, 6
    mov  [rsp+0x44], eax

    ; --- alloc vertex buffer ---
    mov  edx, [rsp+0x40]
    imul edx, MESH_VERTEX_SIZE
    xor  ecx, ecx                  ; LMEM_FIXED
    call LocalAlloc
    test rax, rax
    jz   .fail
    mov  [rsp+0x48], rax

    ; --- alloc index buffer ---
    mov  edx, [rsp+0x44]
    shl  edx, 2                    ; * 4 bytes
    xor  ecx, ecx
    call LocalAlloc
    test rax, rax
    jz   .fail_free_verts
    mov  [rsp+0x50], rax

    ; ========================================================
    ; Fill vertices
    ; ========================================================
    mov  rdi, [rsp+0x48]           ; write head
    xor  r14d, r14d                ; i = 0

.vert_outer:
    cmp  r14d, r13d
    ja   .vert_done                ; i <= stacks

    ; theta = pi * i / stacks
    pxor xmm0, xmm0
    cvtsi2ss xmm0, r14d
    pxor xmm1, xmm1
    cvtsi2ss xmm1, r13d
    divss xmm0, xmm1
    mulss xmm0, [pi_const]
    movss [rsp+0x58], xmm0

    fld  dword [rsp+0x58]
    fsincos                        ; st0=cos, st1=sin
    fstp dword [rsp+0x5C]          ; cos_theta
    fstp dword [rsp+0x60]          ; sin_theta

    xor  r15d, r15d                ; j = 0

.vert_inner:
    cmp  r15d, r12d
    ja   .vert_next_outer          ; j <= slices

    ; phi = 2*pi * j / slices
    pxor xmm0, xmm0
    cvtsi2ss xmm0, r15d
    pxor xmm1, xmm1
    cvtsi2ss xmm1, r12d
    divss xmm0, xmm1
    mulss xmm0, [two_pi_const]
    movss [rsp+0x64], xmm0

    fld  dword [rsp+0x64]
    fsincos
    fstp dword [rsp+0x68]          ; cos_phi
    fstp dword [rsp+0x6C]          ; sin_phi

    ; x = sin_theta * cos_phi
    movss xmm0, [rsp+0x60]
    mulss xmm0, [rsp+0x68]
    ; y = cos_theta
    movss xmm1, [rsp+0x5C]
    ; z = sin_theta * sin_phi
    movss xmm2, [rsp+0x60]
    mulss xmm2, [rsp+0x6C]

    ; write position
    movss [rdi+0], xmm0
    movss [rdi+4], xmm1
    movss [rdi+8], xmm2

    ; write color (warm orange: 1.0, 0.55, 0.35)
    mov  dword [rdi+12], 0x3F800000    ; 1.0
    mov  dword [rdi+16], 0x3F0CCCCD    ; 0.55
    mov  dword [rdi+20], 0x3EB33333    ; 0.35

    ; write normal = position (unit sphere)
    movss [rdi+24], xmm0
    movss [rdi+28], xmm1
    movss [rdi+32], xmm2

    add  rdi, MESH_VERTEX_SIZE
    inc  r15d
    jmp  .vert_inner

.vert_next_outer:
    inc  r14d
    jmp  .vert_outer

.vert_done:

    ; ========================================================
    ; Fill indices
    ; ========================================================
    mov  rdi, [rsp+0x50]
    lea  r10d, [r12d + 1]          ; stride = slices + 1
    xor  r14d, r14d                ; i = 0

.idx_outer:
    cmp  r14d, r13d
    jae  .idx_done                 ; i < stacks

    xor  r15d, r15d

.idx_inner:
    cmp  r15d, r12d
    jae  .idx_next                 ; j < slices

    ; a = i * stride + j
    mov  eax, r14d
    imul eax, r10d
    add  eax, r15d                 ; a
    lea  edx, [rax + r10]          ; b = a + stride

    ; T1: a, a+1, b+1   (CCW from outside)
    mov  [rdi+0], eax
    lea  ecx, [rax + 1]
    mov  [rdi+4], ecx
    lea  ecx, [rdx + 1]
    mov  [rdi+8], ecx

    ; T2: a, b+1, b
    mov  [rdi+12], eax
    lea  ecx, [rdx + 1]
    mov  [rdi+16], ecx
    mov  [rdi+20], edx

    add  rdi, 24
    inc  r15d
    jmp  .idx_inner

.idx_next:
    inc  r14d
    jmp  .idx_outer

.idx_done:

    ; ========================================================
    ; Upload to GPU
    ; ========================================================
    mov  rbx, [rsp+0x30]

    pxor xmm0, xmm0
    movdqu [rbx],    xmm0
    movdqu [rbx+16], xmm0

    ; VAO
    mov  ecx, 1
    lea  rdx, [rbx + MESH_VAO]
    call qword [glGenVertexArrays]
    mov  ecx, [rbx + MESH_VAO]
    call qword [glBindVertexArray]

    ; VBO
    mov  ecx, 1
    lea  rdx, [rbx + MESH_VBO]
    call qword [glGenBuffers]
    mov  ecx, GL_ARRAY_BUFFER
    mov  edx, [rbx + MESH_VBO]
    call qword [glBindBuffer]

    mov  ecx, GL_ARRAY_BUFFER
    mov  edx, [rsp+0x40]
    imul edx, MESH_VERTEX_SIZE
    mov  r8,  [rsp+0x48]
    mov  r9d, GL_STATIC_DRAW
    call qword [glBufferData]

    mov  rcx, rbx
    call mesh_upload_attribs

    ; EBO
    mov  ecx, 1
    lea  rdx, [rbx + MESH_EBO]
    call qword [glGenBuffers]
    mov  ecx, GL_ELEMENT_ARRAY_BUFFER
    mov  edx, [rbx + MESH_EBO]
    call qword [glBindBuffer]

    mov  ecx, GL_ELEMENT_ARRAY_BUFFER
    mov  edx, [rsp+0x44]
    shl  edx, 2
    mov  r8,  [rsp+0x50]
    mov  r9d, GL_STATIC_DRAW
    call qword [glBufferData]

    ; metadata
    mov  eax, [rsp+0x40]
    mov  [rbx + MESH_VERT_COUNT],  eax
    mov  eax, [rsp+0x44]
    mov  [rbx + MESH_INDEX_COUNT], eax
    mov  dword [rbx + MESH_STRIDE], MESH_VERTEX_SIZE

    ; free temp buffers
    mov  rcx, [rsp+0x50]
    call LocalFree
    mov  rcx, [rsp+0x48]
    call LocalFree

    mov  eax, 1
    jmp  .done

.fail_free_verts:
    mov  rcx, [rsp+0x48]
    call LocalFree
.fail:
    xor  eax, eax

.done:
    add  rsp, 0x100
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
mesh_draw:
    push rbx
    sub  rsp, 0x20
    mov  rbx, rcx

    mov  ecx, [rbx + MESH_VAO]
    test ecx, ecx
    jz   .done
    call qword [glBindVertexArray]

    mov  ecx, GL_TRIANGLES
    mov  edx, [rbx + MESH_INDEX_COUNT]
    mov  r8d, GL_UNSIGNED_INT
    xor  r9d, r9d
    call qword [glDrawElements]

.done:
    add  rsp, 0x20
    pop  rbx
    ret

; ============================================================
mesh_destroy:
    push rbx
    sub  rsp, 0x20
    mov  rbx, rcx

    cmp  dword [rbx + MESH_VAO], 0
    je   .no_vao
    mov  ecx, 1
    lea  rdx, [rbx + MESH_VAO]
    call qword [glDeleteVertexArrays]
    mov  dword [rbx + MESH_VAO], 0
.no_vao:

    cmp  dword [rbx + MESH_VBO], 0
    je   .no_vbo
    mov  ecx, 1
    lea  rdx, [rbx + MESH_VBO]
    call qword [glDeleteBuffers]
    mov  dword [rbx + MESH_VBO], 0
.no_vbo:

    cmp  dword [rbx + MESH_EBO], 0
    je   .no_ebo
    mov  ecx, 1
    lea  rdx, [rbx + MESH_EBO]
    call qword [glDeleteBuffers]
    mov  dword [rbx + MESH_EBO], 0
.no_ebo:

    mov  dword [rbx + MESH_INDEX_COUNT], 0
    mov  dword [rbx + MESH_VERT_COUNT],  0

    add  rsp, 0x20
    pop  rbx
    ret
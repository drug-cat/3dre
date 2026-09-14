; ============================================================
; src/render/mesh.asm
; Mesh abstraction: cube, sphere, pyramid
; Vertex layout: pos(3) + color(3) + normal(3) + uv(2) = 44 bytes
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

; ---- Unit cube: 24 vertices, pos + color + normal + uv ----
cube_vertices:
    ; -Z (red) uv per face
    dd -0.5, -0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0,   0.0, 1.0
    dd  0.5, -0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0,   1.0, 1.0
    dd  0.5,  0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0,   1.0, 0.0
    dd -0.5,  0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0,   0.0, 0.0
    ; +Z (green)
    dd -0.5, -0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0,    0.0, 1.0
    dd  0.5, -0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0,    1.0, 1.0
    dd  0.5,  0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0,    1.0, 0.0
    dd -0.5,  0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0,    0.0, 0.0
    ; -Y (blue)
    dd -0.5, -0.5, -0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0,   0.0, 1.0
    dd  0.5, -0.5, -0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0,   1.0, 1.0
    dd  0.5, -0.5,  0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0,   1.0, 0.0
    dd -0.5, -0.5,  0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0,   0.0, 0.0
    ; +Y (yellow)
    dd -0.5,  0.5, -0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0,    0.0, 1.0
    dd  0.5,  0.5, -0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0,    1.0, 1.0
    dd  0.5,  0.5,  0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0,    1.0, 0.0
    dd -0.5,  0.5,  0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0,    0.0, 0.0
    ; -X (magenta)
    dd -0.5, -0.5, -0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0,   0.0, 1.0
    dd -0.5, -0.5,  0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0,   1.0, 1.0
    dd -0.5,  0.5,  0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0,   1.0, 0.0
    dd -0.5,  0.5, -0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0,   0.0, 0.0
    ; +X (cyan)
    dd  0.5, -0.5, -0.5,   0.0, 1.0, 1.0,    1.0, 0.0, 0.0,    0.0, 1.0
    dd  0.5, -0.5,  0.5,   0.0, 1.0, 1.0,    1.0, 0.0, 0.0,    1.0, 1.0
    dd  0.5,  0.5,  0.5,   0.0, 1.0, 1.0,    1.0, 0.0, 0.0,    1.0, 0.0
    dd  0.5,  0.5, -0.5,   0.0, 1.0, 1.0,    1.0, 0.0, 0.0,    0.0, 0.0

align 16
cube_indices:
    dd 0,2,1, 0,3,2
    dd 4,5,6, 4,6,7
    dd 8,9,10, 8,10,11
    dd 12,14,13, 12,15,14
    dd 16,17,18, 16,18,19
    dd 20,22,21, 20,23,22

; ---- Unit pyramid: apex at (0,0.5,0), base square at y=-0.5 ----
; 4 side triangles (12 verts) + 2 base triangles (6 verts) = 18 verts
; Side normals computed for a 1×1 base / height 1 pyramid:
;   n = (0, 0.4472, -0.8944)  for -Z face, etc.
pyramid_vertices:
    ; ---- side 0: -Z face (base[0] → base[1]) ----
    ; apex
    dd  0.0,  0.5,  0.0,   1.0, 0.5, 0.2,    0.0,  0.4472, -0.8944,   0.5, 1.0
    ; base[0] = (-0.5,-0.5,-0.5)
    dd -0.5, -0.5, -0.5,   1.0, 0.5, 0.2,    0.0,  0.4472, -0.8944,   0.0, 0.0
    ; base[1] = ( 0.5,-0.5,-0.5)
    dd  0.5, -0.5, -0.5,   1.0, 0.5, 0.2,    0.0,  0.4472, -0.8944,   1.0, 0.0

    ; ---- side 1: +X face (base[1] → base[2]) ----
    dd  0.0,  0.5,  0.0,   0.8, 0.8, 0.2,    0.8944,  0.4472, 0.0,   0.5, 1.0
    dd  0.5, -0.5, -0.5,   0.8, 0.8, 0.2,    0.8944,  0.4472, 0.0,   0.0, 0.0
    dd  0.5, -0.5,  0.5,   0.8, 0.8, 0.2,    0.8944,  0.4472, 0.0,   1.0, 0.0

    ; ---- side 2: +Z face (base[2] → base[3]) ----
    dd  0.0,  0.5,  0.0,   0.2, 0.8, 0.4,    0.0,  0.4472, 0.8944,   0.5, 1.0
    dd  0.5, -0.5,  0.5,   0.2, 0.8, 0.4,    0.0,  0.4472, 0.8944,   0.0, 0.0
    dd -0.5, -0.5,  0.5,   0.2, 0.8, 0.4,    0.0,  0.4472, 0.8944,   1.0, 0.0

    ; ---- side 3: -X face (base[3] → base[0]) ----
    dd  0.0,  0.5,  0.0,   0.4, 0.4, 0.9,   -0.8944, 0.4472, 0.0,   0.5, 1.0
    dd -0.5, -0.5,  0.5,   0.4, 0.4, 0.9,   -0.8944, 0.4472, 0.0,   0.0, 0.0
    dd -0.5, -0.5, -0.5,   0.4, 0.4, 0.9,   -0.8944, 0.4472, 0.0,   1.0, 0.0

    ; ---- base triangle A: (base[0], base[2], base[1]) — reversed winding ----
    dd -0.5, -0.5, -0.5,   0.5, 0.5, 0.5,    0.0, -1.0, 0.0,   0.0, 1.0
    dd  0.5, -0.5,  0.5,   0.5, 0.5, 0.5,    0.0, -1.0, 0.0,   1.0, 0.0
    dd  0.5, -0.5, -0.5,   0.5, 0.5, 0.5,    0.0, -1.0, 0.0,   1.0, 1.0

    ; ---- base triangle B: (base[0], base[3], base[2]) — reversed winding ----
    dd -0.5, -0.5, -0.5,   0.5, 0.5, 0.5,    0.0, -1.0, 0.0,   0.0, 1.0
    dd -0.5, -0.5,  0.5,   0.5, 0.5, 0.5,    0.0, -1.0, 0.0,   0.0, 0.0
    dd  0.5, -0.5,  0.5,   0.5, 0.5, 0.5,    0.0, -1.0, 0.0,   1.0, 0.0

align 16
pyramid_indices:
    dd 0,1,2, 3,4,5, 6,7,8, 9,10,11, 12,13,14, 15,16,17

section .text
global mesh_create_cube
global mesh_create_sphere
global mesh_create_pyramid
global mesh_draw
global mesh_destroy

; ============================================================
mesh_upload_attribs:
    push rbx
    sub  rsp, 0x30
    mov  rbx, rcx

    mov  ecx, MESH_ATTR_POS
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], MESH_VERTEX_SIZE
    mov  qword [rsp+0x28], MESH_ATTR_POS_OFF
    call qword [glVertexAttribPointer]
    mov  ecx, MESH_ATTR_POS
    call qword [glEnableVertexAttribArray]

    mov  ecx, MESH_ATTR_COLOR
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], MESH_VERTEX_SIZE
    mov  qword [rsp+0x28], MESH_ATTR_COLOR_OFF
    call qword [glVertexAttribPointer]
    mov  ecx, MESH_ATTR_COLOR
    call qword [glEnableVertexAttribArray]

    mov  ecx, MESH_ATTR_NORMAL
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], MESH_VERTEX_SIZE
    mov  qword [rsp+0x28], MESH_ATTR_NORMAL_OFF
    call qword [glVertexAttribPointer]
    mov  ecx, MESH_ATTR_NORMAL
    call qword [glEnableVertexAttribArray]

    mov  ecx, MESH_ATTR_UV
    mov  edx, 2
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], MESH_VERTEX_SIZE
    mov  qword [rsp+0x28], MESH_ATTR_UV_OFF
    call qword [glVertexAttribPointer]
    mov  ecx, MESH_ATTR_UV
    call qword [glEnableVertexAttribArray]

    add  rsp, 0x30
    pop  rbx
    ret

; ============================================================
; mesh_upload_simple(Mesh* m, verts, vert_count, idxs, idx_count)
;   rcx = m, rdx = verts, r8d = vert_count, r9 = idxs, stack = idx_count
; ============================================================
; (inlined into each create function for now)

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
mesh_create_pyramid:
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
    mov  edx, 18 * MESH_VERTEX_SIZE
    lea  r8,  [pyramid_vertices]
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
    mov  edx, 18 * 4
    lea  r8,  [pyramid_indices]
    mov  r9d, GL_STATIC_DRAW
    call qword [glBufferData]

    mov  dword [rbx + MESH_VERT_COUNT],  18
    mov  dword [rbx + MESH_INDEX_COUNT], 18
    mov  dword [rbx + MESH_STRIDE],      MESH_VERTEX_SIZE

    mov  eax, 1
    add  rsp, 0x30
    pop  rbx
    ret

; ============================================================
; mesh_create_sphere(Mesh* m, u32 slices, u32 stacks)
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

    mov  [rsp+0x30], rcx

    cmp  edx, 3
    jae  .s_ge3
    mov  edx, 3
.s_ge3:
    cmp  edx, 64
    jbe  .s_le64
    mov  edx, 64
.s_le64:
    mov  [rsp+0x38], edx

    cmp  r8d, 2
    jae  .st_ge2
    mov  r8d, 2
.st_ge2:
    cmp  r8d, 64
    jbe  .st_le64
    mov  r8d, 64
.st_le64:
    mov  [rsp+0x3C], r8d

    mov  r12d, [rsp+0x38]
    mov  r13d, [rsp+0x3C]

    lea  eax, [r13d + 1]
    lea  ecx, [r12d + 1]
    imul eax, ecx
    mov  [rsp+0x40], eax           ; vert count

    mov  eax, r13d
    imul eax, r12d
    imul eax, 6
    mov  [rsp+0x44], eax           ; idx count

    mov  edx, [rsp+0x40]
    imul edx, MESH_VERTEX_SIZE
    xor  ecx, ecx
    call LocalAlloc
    test rax, rax
    jz   .fail
    mov  [rsp+0x48], rax

    mov  edx, [rsp+0x44]
    shl  edx, 2
    xor  ecx, ecx
    call LocalAlloc
    test rax, rax
    jz   .fail_free_verts
    mov  [rsp+0x50], rax

    ; --- fill vertices ---
    mov  rdi, [rsp+0x48]
    xor  r14d, r14d

.vert_outer:
    cmp  r14d, r13d
    ja   .vert_done

    pxor xmm0, xmm0
    cvtsi2ss xmm0, r14d
    pxor xmm1, xmm1
    cvtsi2ss xmm1, r13d
    divss xmm0, xmm1
    mulss xmm0, [pi_const]
    movss [rsp+0x58], xmm0

    fld  dword [rsp+0x58]
    fsincos
    fstp dword [rsp+0x5C]           ; cos_theta
    fstp dword [rsp+0x60]           ; sin_theta

    xor  r15d, r15d

.vert_inner:
    cmp  r15d, r12d
    ja   .vert_next_outer

    pxor xmm0, xmm0
    cvtsi2ss xmm0, r15d
    pxor xmm1, xmm1
    cvtsi2ss xmm1, r12d
    divss xmm0, xmm1
    mulss xmm0, [two_pi_const]
    movss [rsp+0x64], xmm0

    fld  dword [rsp+0x64]
    fsincos
    fstp dword [rsp+0x68]           ; cos_phi
    fstp dword [rsp+0x6C]           ; sin_phi

    movss xmm0, [rsp+0x60]
    mulss xmm0, [rsp+0x68]          ; x = sin_theta*cos_phi
    movss xmm1, [rsp+0x5C]          ; y = cos_theta
    movss xmm2, [rsp+0x60]
    mulss xmm2, [rsp+0x6C]          ; z = sin_theta*sin_phi

    movss [rdi+0], xmm0
    movss [rdi+4], xmm1
    movss [rdi+8], xmm2

    ; color (orange-ish base)
    mov  dword [rdi+12], 0x3F800000
    mov  dword [rdi+16], 0x3F0CCCCD
    mov  dword [rdi+20], 0x3EB33333

    ; normal = position
    movss [rdi+24], xmm0
    movss [rdi+28], xmm1
    movss [rdi+32], xmm2

    ; uv: u = j/slices, v = i/stacks
    pxor xmm3, xmm3
    cvtsi2ss xmm3, r15d
    pxor xmm4, xmm4
    cvtsi2ss xmm4, r12d
    divss xmm3, xmm4
    movss [rdi+36], xmm3

    pxor xmm5, xmm5
    cvtsi2ss xmm5, r14d
    pxor xmm6, xmm6
    cvtsi2ss xmm6, r13d
    divss xmm5, xmm6
    movss [rdi+40], xmm5

    add  rdi, MESH_VERTEX_SIZE
    inc  r15d
    jmp  .vert_inner

.vert_next_outer:
    inc  r14d
    jmp  .vert_outer

.vert_done:

    ; --- fill indices ---
    mov  rdi, [rsp+0x50]
    lea  r10d, [r12d + 1]
    xor  r14d, r14d

.idx_outer:
    cmp  r14d, r13d
    jae  .idx_done

    xor  r15d, r15d

.idx_inner:
    cmp  r15d, r12d
    jae  .idx_next

    mov  eax, r14d
    imul eax, r10d
    add  eax, r15d
    lea  edx, [rax + r10]

    mov  [rdi+0], eax
    lea  ecx, [rax + 1]
    mov  [rdi+4], ecx
    lea  ecx, [rdx + 1]
    mov  [rdi+8], ecx

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

    ; --- upload ---
    mov  rbx, [rsp+0x30]

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
    mov  edx, [rsp+0x40]
    imul edx, MESH_VERTEX_SIZE
    mov  r8,  [rsp+0x48]
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
    mov  edx, [rsp+0x44]
    shl  edx, 2
    mov  r8,  [rsp+0x50]
    mov  r9d, GL_STATIC_DRAW
    call qword [glBufferData]

    mov  eax, [rsp+0x40]
    mov  [rbx + MESH_VERT_COUNT],  eax
    mov  eax, [rsp+0x44]
    mov  [rbx + MESH_INDEX_COUNT], eax
    mov  dword [rbx + MESH_STRIDE], MESH_VERTEX_SIZE

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
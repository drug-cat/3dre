; ============================================================
; src/render/mesh.asm
; GPU mesh abstraction — VAO/VBO/EBO setup and drawing
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

section .data
align 16
; ---- Unit cube: 24 vertices (4 per face), pos + color + normal ----
; Each row is 9 floats: x,y,z, r,g,b, nx,ny,nz
cube_vertices:
    ; ---- -Z face (red) normal=(0,0,-1) ----
    dd -0.5, -0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0
    dd  0.5, -0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0
    dd  0.5,  0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0
    dd -0.5,  0.5, -0.5,   1.0, 0.0, 0.0,    0.0, 0.0, -1.0
    ; ---- +Z face (green) normal=(0,0,1) ----
    dd -0.5, -0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0
    dd  0.5, -0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0
    dd  0.5,  0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0
    dd -0.5,  0.5,  0.5,   0.0, 1.0, 0.0,    0.0, 0.0, 1.0
    ; ---- -Y face (blue) normal=(0,-1,0) ----
    dd -0.5, -0.5, -0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0
    dd  0.5, -0.5, -0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0
    dd  0.5, -0.5,  0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0
    dd -0.5, -0.5,  0.5,   0.0, 0.0, 1.0,    0.0, -1.0, 0.0
    ; ---- +Y face (yellow) normal=(0,1,0) ----
    dd -0.5,  0.5, -0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0
    dd  0.5,  0.5, -0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0
    dd  0.5,  0.5,  0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0
    dd -0.5,  0.5,  0.5,   1.0, 1.0, 0.0,    0.0, 1.0, 0.0
    ; ---- -X face (magenta) normal=(-1,0,0) ----
    dd -0.5, -0.5, -0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0
    dd -0.5, -0.5,  0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0
    dd -0.5,  0.5,  0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0
    dd -0.5,  0.5, -0.5,   1.0, 0.0, 1.0,    -1.0, 0.0, 0.0
    ; ---- +X face (cyan) normal=(1,0,0) ----
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
global mesh_draw
global mesh_destroy

; ============================================================
mesh_create_cube:
    push rbx
    sub  rsp, 0x30

    mov  rbx, rcx

    pxor xmm0, xmm0
    movdqu [rbx],    xmm0
    movdqu [rbx+16], xmm0

    ; ---- VAO ----
    mov  ecx, 1
    lea  rdx, [rbx + MESH_VAO]
    call qword [glGenVertexArrays]
    mov  ecx, [rbx + MESH_VAO]
    call qword [glBindVertexArray]

    ; ---- VBO ----
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

    ; ---- aPos ----
    mov  ecx, MESH_ATTR_POS
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], MESH_VERTEX_SIZE
    mov  qword [rsp+0x28], MESH_ATTR_POS_OFF
    call qword [glVertexAttribPointer]
    mov  ecx, MESH_ATTR_POS
    call qword [glEnableVertexAttribArray]

    ; ---- aColor ----
    mov  ecx, MESH_ATTR_COLOR
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], MESH_VERTEX_SIZE
    mov  qword [rsp+0x28], MESH_ATTR_COLOR_OFF
    call qword [glVertexAttribPointer]
    mov  ecx, MESH_ATTR_COLOR
    call qword [glEnableVertexAttribArray]

    ; ---- aNormal ----
    mov  ecx, MESH_ATTR_NORMAL
    mov  edx, 3
    mov  r8d, GL_FLOAT
    xor  r9d, r9d
    mov  qword [rsp+0x20], MESH_VERTEX_SIZE
    mov  qword [rsp+0x28], MESH_ATTR_NORMAL_OFF
    call qword [glVertexAttribPointer]
    mov  ecx, MESH_ATTR_NORMAL
    call qword [glEnableVertexAttribArray]

    ; ---- EBO ----
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

    ; ---- metadata ----
    mov  dword [rbx + MESH_VERT_COUNT],  24
    mov  dword [rbx + MESH_INDEX_COUNT], 36
    mov  dword [rbx + MESH_STRIDE],      MESH_VERTEX_SIZE

    mov  eax, 1
    add  rsp, 0x30
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
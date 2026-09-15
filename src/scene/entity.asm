; ============================================================
; src/scene/entity.asm
; Entity slots + physics + AABB/sphere collisions (SAP broad phase)
; ============================================================
BITS 64
default rel

%include "entity.inc"

section .data
align 16
gravity:        dd 9.8
ground_y:       dd -3.95
restitution:    dd 0.35
min_vy:         dd 0.3
friction:       dd 2.5
f_one:          dd 1.0
f_half:         dd 0.5
f_neg_three_q:  dd -0.75
f_epsilon_sq:   dd 0.000001
f_point_one:    dd 0.1
f_tilt:         dd 0.15
abs_mask:       dd 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF

section .bss
align 16
global entities
entities:       resb MAX_ENTITIES * ENTITY_SIZE

; sorted list of entity pointers for SAP
align 16
sorted_entities: resq MAX_ENTITIES

section .text
global entity_init
global entity_spawn_cube
global entity_spawn_sphere
global entity_spawn_pyramid
global entity_destroy
global entity_destroy_last
global entity_update_all
global entity_save_to_buffer
global entity_load_from_buffer

; ============================================================
entity_init:
    push rdi
    lea  rdi, [entities]
    mov  ecx, MAX_ENTITIES * ENTITY_SIZE / 8
    mov  rax, -1
    rep stosq
    pop  rdi
    ret

; ============================================================
entity_spawn_cube:
    mov  ecx, E_TYPE_CUBE
    jmp  entity_spawn_internal

entity_spawn_sphere:
    mov  ecx, E_TYPE_SPHERE
    jmp  entity_spawn_internal

entity_spawn_pyramid:
    mov  ecx, E_TYPE_PYRAMID
    jmp  entity_spawn_internal

; ============================================================
entity_spawn_internal:
    push rbx
    sub  rsp, 0x30

    mov  r8d, ecx
    mov  r9d, edx

    movss [rsp+0x00], xmm0
    movss [rsp+0x04], xmm1
    movss [rsp+0x08], xmm2
    movss [rsp+0x0C], xmm3
    movss [rsp+0x10], xmm4
    movss [rsp+0x14], xmm5
    movss [rsp+0x18], xmm6
    movss [rsp+0x1C], xmm7
    movss [rsp+0x20], xmm8
    movss [rsp+0x24], xmm9

    lea  rbx, [entities]
    mov  r10d, MAX_ENTITIES
    xor  eax, eax

.find:
    cmp  dword [rbx + E_TYPE], E_TYPE_EMPTY
    je   .found
    add  rbx, ENTITY_SIZE
    inc  eax
    dec  r10d
    jnz  .find

    mov  rax, -1
    add  rsp, 0x30
    pop  rbx
    ret

.found:
    mov  r11d, eax

    mov  dword [rbx + E_TYPE], r8d
    mov  dword [rbx + E_FLAGS], 0

    movss xmm0, [rsp+0x00]
    movss [rbx + E_POS + 0], xmm0
    movss xmm0, [rsp+0x04]
    movss [rbx + E_POS + 4], xmm0
    movss xmm0, [rsp+0x08]
    movss [rbx + E_POS + 8], xmm0

    xorps xmm0, xmm0
    movss [rbx + E_ROT_Y], xmm0
    movss [rbx + E_ROT_X], xmm0
    movss [rbx + E_ROT_Z], xmm0

    movss xmm0, [rsp+0x0C]
    movss [rbx + E_ROT_SPEED], xmm0

    mov  eax, 0x3F800000
    mov  dword [rbx + E_SCALE], eax

    movss xmm0, [rsp+0x10]
    movss [rbx + E_COLOR + 0], xmm0
    movss xmm0, [rsp+0x14]
    movss [rbx + E_COLOR + 4], xmm0
    movss xmm0, [rsp+0x18]
    movss [rbx + E_COLOR + 8], xmm0

    mov  dword [rbx + E_TEXTURE], r9d

    movss xmm0, [rsp+0x1C]
    movss [rbx + E_VEL + 0], xmm0
    movss xmm0, [rsp+0x20]
    movss [rbx + E_VEL + 4], xmm0
    movss xmm0, [rsp+0x24]
    movss [rbx + E_VEL + 8], xmm0

    mov  eax, 0x3F000000
    cmp  r8d, E_TYPE_SPHERE
    jne  .hh_set
    mov  eax, 0x3F800000
.hh_set:
    mov  dword [rbx + E_HALF_H], eax

    mov  dword [rbx + E_PAD2], 0
    mov  dword [rbx + E_PAD3], 0

    mov  eax, r11d

    add  rsp, 0x30
    pop  rbx
    ret

; ============================================================
entity_destroy:
    cmp  ecx, MAX_ENTITIES
    jae  .done
    imul eax, ecx, ENTITY_SIZE
    lea  rdx, [entities]
    add  rdx, rax
    mov  dword [rdx + E_TYPE], E_TYPE_EMPTY
.done:
    ret

; ============================================================
entity_destroy_last:
    lea  rax, [entities + (MAX_ENTITIES - 1) * ENTITY_SIZE]
    mov  ecx, MAX_ENTITIES
.find:
    cmp  dword [rax + E_TYPE], E_TYPE_EMPTY
    jne  .found
    sub  rax, ENTITY_SIZE
    dec  ecx
    jnz  .find
    ret
.found:
    mov  dword [rax + E_TYPE], E_TYPE_EMPTY
    ret

; ============================================================
; entity_update_all(dt)  ; xmm0 = dt
; ============================================================
entity_update_all:
    push rbx
    push r12
    sub  rsp, 0x28

    movss [rsp], xmm0
    movups xmm15, [abs_mask]

    lea  rbx, [entities]
    mov  r12d, MAX_ENTITIES

.loop:
    cmp  dword [rbx + E_TYPE], E_TYPE_EMPTY
    je   .next

    cmp  dword [rbx + E_TYPE], E_TYPE_SPHERE
    je   .sphere_roll

    movss xmm0, [rsp]
    mulss xmm0, [rbx + E_ROT_SPEED]
    addss xmm0, [rbx + E_ROT_Y]
    movss [rbx + E_ROT_Y], xmm0
    jmp  .rot_done

.sphere_roll:
    movss xmm0, [rbx + E_VEL + 8]
    mulss xmm0, [rsp]
    divss xmm0, [rbx + E_HALF_H]
    addss xmm0, [rbx + E_ROT_X]
    movss [rbx + E_ROT_X], xmm0

    movss xmm0, [rbx + E_VEL + 0]
    mulss xmm0, [rsp]
    divss xmm0, [rbx + E_HALF_H]
    xorps xmm1, xmm1
    subss xmm1, xmm0
    addss xmm1, [rbx + E_ROT_Z]
    movss [rbx + E_ROT_Z], xmm1

.rot_done:
    movss xmm0, [gravity]
    mulss xmm0, [rsp]
    movss xmm1, [rbx + E_VEL + 4]
    subss xmm1, xmm0
    movss [rbx + E_VEL + 4], xmm1

    movss xmm0, [rbx + E_VEL + 0]
    mulss xmm0, [rsp]
    addss xmm0, [rbx + E_POS + 0]
    movss [rbx + E_POS + 0], xmm0

    movss xmm0, [rbx + E_VEL + 4]
    mulss xmm0, [rsp]
    addss xmm0, [rbx + E_POS + 4]
    movss [rbx + E_POS + 4], xmm0

    movss xmm0, [rbx + E_VEL + 8]
    mulss xmm0, [rsp]
    addss xmm0, [rbx + E_POS + 8]
    movss [rbx + E_POS + 8], xmm0

    movss xmm1, [ground_y]
    addss xmm1, [rbx + E_HALF_H]

    movss xmm0, [rbx + E_POS + 4]
    comiss xmm0, xmm1
    jae  .next

    movss [rbx + E_POS + 4], xmm1

    movss xmm0, [rbx + E_VEL + 4]
    xorps xmm2, xmm2
    subss xmm2, xmm0
    mulss xmm2, [restitution]
    movss [rbx + E_VEL + 4], xmm2

    movaps xmm3, xmm2
    andps  xmm3, xmm15
    movss  xmm4, [min_vy]
    comiss xmm3, xmm4
    jae  .friction
    mov  dword [rbx + E_VEL + 4], 0

.friction:
    movss xmm5, [friction]
    mulss xmm5, [rsp]
    movss xmm6, [f_one]
    subss xmm6, xmm5
    xorps xmm7, xmm7
    maxss xmm6, xmm7

    movss xmm0, [rbx + E_VEL + 0]
    mulss xmm0, xmm6
    movss [rbx + E_VEL + 0], xmm0

    movss xmm0, [rbx + E_VEL + 8]
    mulss xmm0, xmm6
    movss [rbx + E_VEL + 8], xmm0

    movss xmm0, [rbx + E_VEL + 0]
    andps xmm0, xmm15
    movss xmm1, [min_vy]
    comiss xmm0, xmm1
    jae  .next

    movss xmm0, [rbx + E_VEL + 8]
    andps xmm0, xmm15
    comiss xmm0, xmm1
    jae  .next

    movss xmm0, [rbx + E_ROT_SPEED]
    mulss xmm0, xmm6
    movss [rbx + E_ROT_SPEED], xmm0

.next:
    add  rbx, ENTITY_SIZE
    dec  r12d
    jnz  .loop

    call entity_resolve_collisions

    add  rsp, 0x28
    pop  r12
    pop  rbx
    ret

; ============================================================
; entity_resolve_collisions — Sweep-and-Prune broad phase
;   Gather → Sort by pos.x → Sweep pairs where x is close
; ============================================================
entity_resolve_collisions:
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 0x48

    movups xmm15, [abs_mask]

    ; ---- 1. Gather pointers to live entities ----
    lea  r12, [sorted_entities]
    lea  rbx, [entities]
    xor  r13d, r13d
    mov  ecx, MAX_ENTITIES

.gather:
    cmp  dword [rbx + E_TYPE], E_TYPE_EMPTY
    je   .gskip
    mov  [r12 + r13*8], rbx
    inc  r13d
.gskip:
    add  rbx, ENTITY_SIZE
    dec  ecx
    jnz  .gather

    cmp  r13d, 2
    jb   .done

    ; ---- 2. Insertion sort by pos.x ----
    mov  r14d, 1
.sort_outer:
    cmp  r14d, r13d
    jae  .sort_done

    mov  rax, [r12 + r14*8]
    movss xmm0, [rax + E_POS + 0]

    mov  ebp, r14d
.sort_inner:
    test ebp, ebp
    jz   .place
    mov  rbx, [r12 + rbp*8 - 8]
    movss xmm1, [rbx + E_POS + 0]
    comiss xmm1, xmm0
    jbe  .place
    mov  [r12 + rbp*8], rbx
    dec  ebp
    jmp  .sort_inner
.place:
    mov  [r12 + rbp*8], rax
    inc  r14d
    jmp  .sort_outer
.sort_done:

    ; ---- 3. Sweep ----
    xor  r10d, r10d                ; i index
.outer_i:
    cmp  r10d, r13d
    jae  .done

    mov  r14, [r12 + r10*8]

    ; threshold = half_i + 1.0 (max half for any entity)
    movss xmm0, [r14 + E_POS + 0]
    movss [rsp+0x00], xmm0
    movss xmm1, [r14 + E_HALF_H]
    addss xmm1, [f_one]
    movss [rsp+0x04], xmm1

    lea  r11d, [r10d + 1]          ; j = i+1
.inner_j:
    cmp  r11d, r13d
    jae  .next_i

    mov  r15, [r12 + r11*8]
    movss xmm0, [r15 + E_POS + 0]
    subss xmm0, [rsp+0x00]
    comiss xmm0, [rsp+0x04]
    ja   .next_i                   ; j is far in x → no more pairs for this i

    ; ---- narrow-phase dispatch ----
    cmp  dword [r14 + E_TYPE], E_TYPE_SPHERE
    je   .sphere_path
    cmp  dword [r15 + E_TYPE], E_TYPE_SPHERE
    je   .sphere_path

    ; ============================================
    ; BOX-BOX (AABB along min-overlap axis)
    ; ============================================
    movss xmm0, [r15 + E_POS + 0]
    subss xmm0, [r14 + E_POS + 0]
    movss [rsp+0x08], xmm0
    movss xmm1, [r15 + E_POS + 4]
    subss xmm1, [r14 + E_POS + 4]
    movss [rsp+0x0C], xmm1
    movss xmm2, [r15 + E_POS + 8]
    subss xmm2, [r14 + E_POS + 8]
    movss [rsp+0x10], xmm2

    movss xmm3, [r14 + E_HALF_H]
    addss xmm3, [r15 + E_HALF_H]

    movaps xmm4, xmm0
    andps  xmm4, xmm15
    movaps xmm5, xmm3
    subss  xmm5, xmm4
    xorps  xmm6, xmm6
    comiss xmm5, xmm6
    jbe  .next_j

    movaps xmm4, xmm1
    andps  xmm4, xmm15
    movaps xmm7, xmm3
    subss  xmm7, xmm4
    comiss xmm7, xmm6
    jbe  .next_j

    movaps xmm4, xmm2
    andps  xmm4, xmm15
    movaps xmm8, xmm3
    subss  xmm8, xmm4
    comiss xmm8, xmm6
    jbe  .next_j

    movaps xmm9, xmm5
    xor  eax, eax
    comiss xmm9, xmm7
    jbe  .box_chk_z
    movaps xmm9, xmm7
    mov  eax, 1
.box_chk_z:
    comiss xmm9, xmm8
    jbe  .box_axis_ready
    movaps xmm9, xmm8
    mov  eax, 2
.box_axis_ready:
    mulss xmm9, [f_half]
    movss [rsp+0x14], xmm9

    mov  r9d, 0x3F800000
    mov  r8d, 0xBF800000

    cmp  eax, 0
    je   .box_axis_x
    cmp  eax, 1
    je   .box_axis_y

    xorps xmm10, xmm10
    movss [rsp+0x08], xmm10
    movss [rsp+0x0C], xmm10
    movss xmm11, [rsp+0x10]
    xorps xmm12, xmm12
    comiss xmm11, xmm12
    jbe  .box_z_neg
    movd xmm10, r9d
    movss [rsp+0x10], xmm10
    jmp  .apply_impulse
.box_z_neg:
    movd xmm10, r8d
    movss [rsp+0x10], xmm10
    jmp  .apply_impulse

.box_axis_x:
    movss xmm11, [rsp+0x08]
    xorps xmm10, xmm10
    movss [rsp+0x0C], xmm10
    movss [rsp+0x10], xmm10
    xorps xmm12, xmm12
    comiss xmm11, xmm12
    jbe  .box_x_neg
    movd xmm10, r9d
    movss [rsp+0x08], xmm10
    jmp  .apply_impulse
.box_x_neg:
    movd xmm10, r8d
    movss [rsp+0x08], xmm10
    jmp  .apply_impulse

.box_axis_y:
    movss xmm11, [rsp+0x0C]
    xorps xmm10, xmm10
    movss [rsp+0x08], xmm10
    movss [rsp+0x10], xmm10
    xorps xmm12, xmm12
    comiss xmm11, xmm12
    jbe  .box_y_neg
    movd xmm10, r9d
    movss [rsp+0x0C], xmm10
    jmp  .apply_impulse
.box_y_neg:
    movd xmm10, r8d
    movss [rsp+0x0C], xmm10
    jmp  .apply_impulse

    ; ============================================
    ; SPHERE (sphere-sphere)
    ; ============================================
.sphere_path:
    movss xmm0, [r15 + E_POS + 0]
    subss xmm0, [r14 + E_POS + 0]
    movss [rsp+0x08], xmm0
    movss xmm1, [r15 + E_POS + 4]
    subss xmm1, [r14 + E_POS + 4]
    movss [rsp+0x0C], xmm1
    movss xmm2, [r15 + E_POS + 8]
    subss xmm2, [r14 + E_POS + 8]
    movss [rsp+0x10], xmm2

    movaps xmm3, xmm0
    mulss  xmm3, xmm3
    movaps xmm4, xmm1
    mulss  xmm4, xmm4
    addss  xmm3, xmm4
    movaps xmm4, xmm2
    mulss  xmm4, xmm4
    addss  xmm3, xmm4

    movss xmm4, [r14 + E_HALF_H]
    addss xmm4, [r15 + E_HALF_H]
    mulss xmm4, xmm4

    comiss xmm3, xmm4
    jae  .next_j

    movss xmm5, [f_epsilon_sq]
    comiss xmm3, xmm5
    jb   .next_j

    sqrtss xmm5, xmm3
    movss [rsp+0x18], xmm5

    movss xmm6, [f_one]
    divss xmm6, xmm5

    movss xmm7, [rsp+0x08]
    mulss xmm7, xmm6
    movss [rsp+0x08], xmm7
    movss xmm7, [rsp+0x0C]
    mulss xmm7, xmm6
    movss [rsp+0x0C], xmm7
    movss xmm7, [rsp+0x10]
    mulss xmm7, xmm6
    movss [rsp+0x10], xmm7

    ; tilt fix for two spheres
    cmp  dword [r14 + E_TYPE], E_TYPE_SPHERE
    jne  .no_tilt
    cmp  dword [r15 + E_TYPE], E_TYPE_SPHERE
    jne  .no_tilt

    movss xmm8, [rsp+0x08]
    andps xmm8, xmm15
    movss xmm9, [f_point_one]
    comiss xmm8, xmm9
    jae  .no_tilt

    movss xmm8, [rsp+0x10]
    andps xmm8, xmm15
    comiss xmm8, xmm9
    jae  .no_tilt

    movss xmm8, [rsp+0x08]
    addss xmm8, [f_tilt]
    movss [rsp+0x08], xmm8

    movaps xmm9, xmm8
    mulss  xmm9, xmm9
    movss  xmm10, [rsp+0x0C]
    mulss  xmm10, xmm10
    addss  xmm9, xmm10
    movss  xmm10, [rsp+0x10]
    mulss  xmm10, xmm10
    addss  xmm9, xmm10

    sqrtss xmm9, xmm9
    movss  xmm10, [f_one]
    divss  xmm10, xmm9

    movss xmm8, [rsp+0x08]
    mulss xmm8, xmm10
    movss [rsp+0x08], xmm8
    movss xmm8, [rsp+0x0C]
    mulss xmm8, xmm10
    movss [rsp+0x0C], xmm8
    movss xmm8, [rsp+0x10]
    mulss xmm8, xmm10
    movss [rsp+0x10], xmm8

.no_tilt:
    movss xmm7, [r14 + E_HALF_H]
    addss xmm7, [r15 + E_HALF_H]
    subss xmm7, xmm5
    mulss xmm7, [f_half]
    movss [rsp+0x14], xmm7

; ============================================================
; APPLY IMPULSE (shared by both paths)
; ============================================================
.apply_impulse:
    ; ei.pos -= n * hp
    movss xmm7, [rsp+0x08]
    mulss xmm7, [rsp+0x14]
    movss xmm8, [r14 + E_POS + 0]
    subss xmm8, xmm7
    movss [r14 + E_POS + 0], xmm8

    movss xmm7, [rsp+0x0C]
    mulss xmm7, [rsp+0x14]
    movss xmm8, [r14 + E_POS + 4]
    subss xmm8, xmm7
    movss [r14 + E_POS + 4], xmm8

    movss xmm7, [rsp+0x10]
    mulss xmm7, [rsp+0x14]
    movss xmm8, [r14 + E_POS + 8]
    subss xmm8, xmm7
    movss [r14 + E_POS + 8], xmm8

    ; ej.pos += n * hp
    movss xmm7, [rsp+0x08]
    mulss xmm7, [rsp+0x14]
    movss xmm8, [r15 + E_POS + 0]
    addss xmm8, xmm7
    movss [r15 + E_POS + 0], xmm8

    movss xmm7, [rsp+0x0C]
    mulss xmm7, [rsp+0x14]
    movss xmm8, [r15 + E_POS + 4]
    addss xmm8, xmm7
    movss [r15 + E_POS + 4], xmm8

    movss xmm7, [rsp+0x10]
    mulss xmm7, [rsp+0x14]
    movss xmm8, [r15 + E_POS + 8]
    addss xmm8, xmm7
    movss [r15 + E_POS + 8], xmm8

    ; v_rel = (vB - vA) · n
    movss xmm0, [r15 + E_VEL + 0]
    subss xmm0, [r14 + E_VEL + 0]
    movss xmm1, [r15 + E_VEL + 4]
    subss xmm1, [r14 + E_VEL + 4]
    movss xmm2, [r15 + E_VEL + 8]
    subss xmm2, [r14 + E_VEL + 8]

    mulss xmm0, [rsp+0x08]
    mulss xmm1, [rsp+0x0C]
    mulss xmm2, [rsp+0x10]
    addss xmm0, xmm1
    addss xmm0, xmm2

    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jae  .next_j

    mulss xmm0, [f_neg_three_q]

    ; vA -= n * J
    movss xmm7, [rsp+0x08]
    mulss xmm7, xmm0
    movss xmm8, [r14 + E_VEL + 0]
    subss xmm8, xmm7
    movss [r14 + E_VEL + 0], xmm8

    movss xmm7, [rsp+0x0C]
    mulss xmm7, xmm0
    movss xmm8, [r14 + E_VEL + 4]
    subss xmm8, xmm7
    movss [r14 + E_VEL + 4], xmm8

    movss xmm7, [rsp+0x10]
    mulss xmm7, xmm0
    movss xmm8, [r14 + E_VEL + 8]
    subss xmm8, xmm7
    movss [r14 + E_VEL + 8], xmm8

    ; vB += n * J
    movss xmm7, [rsp+0x08]
    mulss xmm7, xmm0
    movss xmm8, [r15 + E_VEL + 0]
    addss xmm8, xmm7
    movss [r15 + E_VEL + 0], xmm8

    movss xmm7, [rsp+0x0C]
    mulss xmm7, xmm0
    movss xmm8, [r15 + E_VEL + 4]
    addss xmm8, xmm7
    movss [r15 + E_VEL + 4], xmm8

    movss xmm7, [rsp+0x10]
    mulss xmm7, xmm0
    movss xmm8, [r15 + E_VEL + 8]
    addss xmm8, xmm7
    movss [r15 + E_VEL + 8], xmm8

.next_j:
    inc  r11d
    jmp  .inner_j

.next_i:
    inc  r10d
    jmp  .outer_i

.done:
    add  rsp, 0x48
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    ret

; ============================================================
; entity_save_to_buffer / entity_load_from_buffer
; (unchanged from previous version)
; ============================================================
entity_save_to_buffer:
    push rbx
    push rsi
    push rdi
    push r12
    sub  rsp, 0x20

    mov  rdi, rcx
    lea  rbx, [entities]
    mov  r12d, MAX_ENTITIES
    xor  rsi, rsi

.loop:
    cmp  dword [rbx + E_TYPE], E_TYPE_EMPTY
    je   .skip

    mov  eax, [rbx + E_TYPE]
    mov  [rdi + 0], eax
    mov  eax, [rbx + E_TEXTURE]
    mov  [rdi + 4], eax

    mov  eax, [rbx + E_POS + 0]
    mov  [rdi + 8], eax
    mov  eax, [rbx + E_POS + 4]
    mov  [rdi + 12], eax
    mov  eax, [rbx + E_POS + 8]
    mov  [rdi + 16], eax

    mov  eax, [rbx + E_ROT_X]
    mov  [rdi + 20], eax
    mov  eax, [rbx + E_ROT_Y]
    mov  [rdi + 24], eax
    mov  eax, [rbx + E_ROT_Z]
    mov  [rdi + 28], eax

    mov  eax, [rbx + E_ROT_SPEED]
    mov  [rdi + 32], eax

    mov  eax, [rbx + E_VEL + 0]
    mov  [rdi + 36], eax
    mov  eax, [rbx + E_VEL + 4]
    mov  [rdi + 40], eax
    mov  eax, [rbx + E_VEL + 8]
    mov  [rdi + 44], eax

    mov  eax, [rbx + E_COLOR + 0]
    mov  [rdi + 48], eax
    mov  eax, [rbx + E_COLOR + 4]
    mov  [rdi + 52], eax
    mov  eax, [rbx + E_COLOR + 8]
    mov  [rdi + 56], eax

    mov  eax, [rbx + E_SCALE]
    mov  [rdi + 60], eax

    mov  eax, [rbx + E_HALF_H]
    mov  [rdi + 64], eax

    add  rdi, 68
    add  rsi, 68

.skip:
    add  rbx, ENTITY_SIZE
    dec  r12d
    jnz  .loop

    mov  rax, rsi
    add  rsp, 0x20
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbx
    ret

entity_load_from_buffer:
    push rbx
    push rsi
    push rdi
    push r12
    sub  rsp, 0x20

    mov  rdi, rcx
    mov  r12d, edx

    call entity_init

    xor  esi, esi

.load_loop:
    cmp  esi, r12d
    jae  .done

    lea  rax, [entities]
    mov  ecx, MAX_ENTITIES
.find:
    cmp  dword [rax + E_TYPE], E_TYPE_EMPTY
    je   .found
    add  rax, ENTITY_SIZE
    dec  ecx
    jnz  .find
    jmp  .done

.found:
    mov  rbx, rax

    pxor xmm0, xmm0
    movdqu [rbx +  0], xmm0
    movdqu [rbx + 16], xmm0
    movdqu [rbx + 32], xmm0
    movdqu [rbx + 48], xmm0
    movdqu [rbx + 64], xmm0

    mov  eax, [rdi + 0]
    mov  [rbx + E_TYPE], eax
    mov  eax, [rdi + 4]
    mov  [rbx + E_TEXTURE], eax

    mov  eax, [rdi + 8]
    mov  [rbx + E_POS + 0], eax
    mov  eax, [rdi + 12]
    mov  [rbx + E_POS + 4], eax
    mov  eax, [rdi + 16]
    mov  [rbx + E_POS + 8], eax

    mov  eax, [rdi + 20]
    mov  [rbx + E_ROT_X], eax
    mov  eax, [rdi + 24]
    mov  [rbx + E_ROT_Y], eax
    mov  eax, [rdi + 28]
    mov  [rbx + E_ROT_Z], eax

    mov  eax, [rdi + 32]
    mov  [rbx + E_ROT_SPEED], eax

    mov  eax, [rdi + 36]
    mov  [rbx + E_VEL + 0], eax
    mov  eax, [rdi + 40]
    mov  [rbx + E_VEL + 4], eax
    mov  eax, [rdi + 44]
    mov  [rbx + E_VEL + 8], eax

    mov  eax, [rdi + 48]
    mov  [rbx + E_COLOR + 0], eax
    mov  eax, [rdi + 52]
    mov  [rbx + E_COLOR + 4], eax
    mov  eax, [rdi + 56]
    mov  [rbx + E_COLOR + 8], eax

    mov  eax, [rdi + 60]
    mov  [rbx + E_SCALE], eax

    mov  eax, [rdi + 64]
    mov  [rbx + E_HALF_H], eax

    add  rdi, 68
    inc  esi
    jmp  .load_loop

.done:
    add  rsp, 0x20
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbx
    ret
; ============================================================
; src/scene/entity.asm
; Entities + physics + rolling spheres + unstable stacking
; ============================================================
BITS 64
default rel

%include "entity.inc"

section .data
align 16
gravity:        dd 9.8
ground_y:       dd -4.0
restitution:    dd 0.35
min_vy:         dd 0.3
friction:       dd 2.5
f_one:          dd 1.0
f_half:         dd 0.5
f_neg_three_q:  dd -0.75
f_epsilon_sq:   dd 0.000001
f_point_one:    dd 0.1
f_tilt:         dd 0.15            ; horizontal nudge applied to near-vertical normals
abs_mask:       dd 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF

section .bss
align 16
global entities
entities:       resb MAX_ENTITIES * ENTITY_SIZE

section .text
global entity_init
global entity_spawn_cube
global entity_spawn_sphere
global entity_spawn_pyramid
global entity_destroy
global entity_destroy_last
global entity_update_all

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
; entity_spawn_internal
;   ecx = type, edx = texture id
;   xmm0..2 = pos, xmm3 = rot_speed, xmm4..6 = color
;   xmm7..9 = velocity
; Returns rax = index or -1
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
    xor  eax, eax                  ; index counter

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
    mov  r11d, eax                 ; save index

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

    ; half-height / radius
    mov  eax, 0x3F000000           ; 0.5f
    cmp  r8d, E_TYPE_SPHERE
    jne  .hh_set
    mov  eax, 0x3F800000           ; 1.0f
.hh_set:
    mov  dword [rbx + E_HALF_H], eax

    mov  dword [rbx + E_PAD2], 0
    mov  dword [rbx + E_PAD3], 0

    mov  eax, r11d                 ; return index

    add  rsp, 0x30
    pop  rbx
    ret

; ============================================================
entity_destroy:                    ; ecx = index
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

    ; ---- rotation: spheres roll, others spin around Y ----
    cmp  dword [rbx + E_TYPE], E_TYPE_SPHERE
    je   .sphere_roll

    movss xmm0, [rsp]
    mulss xmm0, [rbx + E_ROT_SPEED]
    addss xmm0, [rbx + E_ROT_Y]
    movss [rbx + E_ROT_Y], xmm0
    jmp  .rot_done

.sphere_roll:
    ; rot_x += vel.z * dt / r
    movss xmm0, [rbx + E_VEL + 8]
    mulss xmm0, [rsp]
    divss xmm0, [rbx + E_HALF_H]
    addss xmm0, [rbx + E_ROT_X]
    movss [rbx + E_ROT_X], xmm0

    ; rot_z -= vel.x * dt / r
    movss xmm0, [rbx + E_VEL + 0]
    mulss xmm0, [rsp]
    divss xmm0, [rbx + E_HALF_H]
    xorps xmm1, xmm1
    subss xmm1, xmm0
    addss xmm1, [rbx + E_ROT_Z]
    movss [rbx + E_ROT_Z], xmm1

.rot_done:

    ; ---- gravity ----
    movss xmm0, [gravity]
    mulss xmm0, [rsp]
    movss xmm1, [rbx + E_VEL + 4]
    subss xmm1, xmm0
    movss [rbx + E_VEL + 4], xmm1

    ; ---- integrate ----
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

    ; ---- ground ----
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

    ; both nearly zero → damp spin as well
    movss xmm0, [rbx + E_ROT_SPEED]
    mulss xmm0, xmm6
    movss [rbx + E_ROT_SPEED], xmm0

.next:
    add  rbx, ENTITY_SIZE
    dec  r12d
    jnz  .loop

    ; ---- Pass 2: entity-entity collision ----
    call entity_resolve_collisions

    add  rsp, 0x28
    pop  r12
    pop  rbx
    ret

; ============================================================
; entity_resolve_collisions — O(n²) sphere-sphere pairs
; ============================================================
entity_resolve_collisions:
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 0x40

    ; stack layout:
    ;   [rsp+0x00..0x0B] : n (nx, ny, nz)
    ;   [rsp+0x0C]       : dist
    ;   [rsp+0x10]       : half_penetration
    ;   [rsp+0x14]       : n_len (for renormalize after tilt)
    ;   [rsp+0x18]       : tmp

    movups xmm15, [abs_mask]

    mov  r13d, MAX_ENTITIES
    lea  r14, [entities]
    xor  r12d, r12d

.outer:
    cmp  r12d, r13d
    jae  .outer_done

    cmp  dword [r14 + E_TYPE], E_TYPE_EMPTY
    je   .outer_next

    lea  r15, [r14 + ENTITY_SIZE]
    lea  ebp, [r12d + 1]

.inner:
    cmp  ebp, r13d
    jae  .outer_next

    cmp  dword [r15 + E_TYPE], E_TYPE_EMPTY
    je   .inner_next

    ; ---- d = pos_j - pos_i ----
    movss xmm0, [r15 + E_POS + 0]
    subss xmm0, [r14 + E_POS + 0]
    movss [rsp+0x00], xmm0

    movss xmm1, [r15 + E_POS + 4]
    subss xmm1, [r14 + E_POS + 4]
    movss [rsp+0x04], xmm1

    movss xmm2, [r15 + E_POS + 8]
    subss xmm2, [r14 + E_POS + 8]
    movss [rsp+0x08], xmm2

    ; ---- dist_sq ----
    movaps xmm3, xmm0
    mulss  xmm3, xmm3
    movaps xmm4, xmm1
    mulss  xmm4, xmm4
    addss  xmm3, xmm4
    movaps xmm4, xmm2
    mulss  xmm4, xmm4
    addss  xmm3, xmm4

    ; ---- r_sum² ----
    movss xmm4, [r14 + E_HALF_H]
    addss xmm4, [r15 + E_HALF_H]
    mulss xmm4, xmm4

    comiss xmm3, xmm4
    jae  .inner_next

    movss xmm5, [f_epsilon_sq]
    comiss xmm3, xmm5
    jb   .inner_next

    ; ---- dist, inv_dist ----
    sqrtss xmm5, xmm3
    movss [rsp+0x0C], xmm5

    movss xmm6, [f_one]
    divss xmm6, xmm5               ; inv_dist

    ; ---- normal = d * inv_dist ----
    movss xmm7, [rsp+0x00]
    mulss xmm7, xmm6
    movss [rsp+0x00], xmm7

    movss xmm7, [rsp+0x04]
    mulss xmm7, xmm6
    movss [rsp+0x04], xmm7

    movss xmm7, [rsp+0x08]
    mulss xmm7, xmm6
    movss [rsp+0x08], xmm7

    ; ---- Unstable stacking fix ----
    ; If both are spheres AND normal is nearly vertical, tilt it in +X
    cmp  dword [r14 + E_TYPE], E_TYPE_SPHERE
    jne  .no_tilt
    cmp  dword [r15 + E_TYPE], E_TYPE_SPHERE
    jne  .no_tilt

    ; |ny| should be ~1; check |nx| and |nz| are small
    movss xmm8, [rsp+0x00]
    andps xmm8, xmm15
    movss xmm9, [f_point_one]
    comiss xmm8, xmm9
    jae  .no_tilt

    movss xmm8, [rsp+0x08]
    andps xmm8, xmm15
    comiss xmm8, xmm9
    jae  .no_tilt

    ; tilt: nx += 0.15, then renormalize
    movss xmm8, [rsp+0x00]
    addss xmm8, [f_tilt]
    movss [rsp+0x00], xmm8

    ; recompute length
    movaps xmm9, xmm8
    mulss  xmm9, xmm9
    movss  xmm10, [rsp+0x04]
    mulss  xmm10, xmm10
    addss  xmm9, xmm10
    movss  xmm10, [rsp+0x08]
    mulss  xmm10, xmm10
    addss  xmm9, xmm10

    sqrtss xmm9, xmm9
    movss  xmm10, [f_one]
    divss  xmm10, xmm9
    movss  [rsp+0x14], xmm10       ; inv_len

    movss xmm8, [rsp+0x00]
    mulss xmm8, xmm10
    movss [rsp+0x00], xmm8
    movss xmm8, [rsp+0x04]
    mulss xmm8, xmm10
    movss [rsp+0x04], xmm8
    movss xmm8, [rsp+0x08]
    mulss xmm8, xmm10
    movss [rsp+0x08], xmm8

.no_tilt:

    ; ---- half_penetration ----
    movss xmm7, [r14 + E_HALF_H]
    addss xmm7, [r15 + E_HALF_H]
    subss xmm7, xmm5
    mulss xmm7, [f_half]
    movss [rsp+0x10], xmm7

    ; ---- ei.pos -= n * hp ----
    movss xmm7, [rsp+0x00]
    mulss xmm7, [rsp+0x10]
    movss xmm8, [r14 + E_POS + 0]
    subss xmm8, xmm7
    movss [r14 + E_POS + 0], xmm8

    movss xmm7, [rsp+0x04]
    mulss xmm7, [rsp+0x10]
    movss xmm8, [r14 + E_POS + 4]
    subss xmm8, xmm7
    movss [r14 + E_POS + 4], xmm8

    movss xmm7, [rsp+0x08]
    mulss xmm7, [rsp+0x10]
    movss xmm8, [r14 + E_POS + 8]
    subss xmm8, xmm7
    movss [r14 + E_POS + 8], xmm8

    ; ---- ej.pos += n * hp ----
    movss xmm7, [rsp+0x00]
    mulss xmm7, [rsp+0x10]
    movss xmm8, [r15 + E_POS + 0]
    addss xmm8, xmm7
    movss [r15 + E_POS + 0], xmm8

    movss xmm7, [rsp+0x04]
    mulss xmm7, [rsp+0x10]
    movss xmm8, [r15 + E_POS + 4]
    addss xmm8, xmm7
    movss [r15 + E_POS + 4], xmm8

    movss xmm7, [rsp+0x08]
    mulss xmm7, [rsp+0x10]
    movss xmm8, [r15 + E_POS + 8]
    addss xmm8, xmm7
    movss [r15 + E_POS + 8], xmm8

    ; ---- v_rel · n ----
    movss xmm0, [r15 + E_VEL + 0]
    subss xmm0, [r14 + E_VEL + 0]
    movss xmm1, [r15 + E_VEL + 4]
    subss xmm1, [r14 + E_VEL + 4]
    movss xmm2, [r15 + E_VEL + 8]
    subss xmm2, [r14 + E_VEL + 8]

    mulss xmm0, [rsp+0x00]
    mulss xmm1, [rsp+0x04]
    mulss xmm2, [rsp+0x08]
    addss xmm0, xmm1
    addss xmm0, xmm2

    xorps xmm1, xmm1
    comiss xmm0, xmm1
    jae  .inner_next

    mulss xmm0, [f_neg_three_q]    ; J

    ; ---- ei.vel -= n * J ----
    movss xmm7, [rsp+0x00]
    mulss xmm7, xmm0
    movss xmm8, [r14 + E_VEL + 0]
    subss xmm8, xmm7
    movss [r14 + E_VEL + 0], xmm8

    movss xmm7, [rsp+0x04]
    mulss xmm7, xmm0
    movss xmm8, [r14 + E_VEL + 4]
    subss xmm8, xmm7
    movss [r14 + E_VEL + 4], xmm8

    movss xmm7, [rsp+0x08]
    mulss xmm7, xmm0
    movss xmm8, [r14 + E_VEL + 8]
    subss xmm8, xmm7
    movss [r14 + E_VEL + 8], xmm8

    ; ---- ej.vel += n * J ----
    movss xmm7, [rsp+0x00]
    mulss xmm7, xmm0
    movss xmm8, [r15 + E_VEL + 0]
    addss xmm8, xmm7
    movss [r15 + E_VEL + 0], xmm8

    movss xmm7, [rsp+0x04]
    mulss xmm7, xmm0
    movss xmm8, [r15 + E_VEL + 4]
    addss xmm8, xmm7
    movss [r15 + E_VEL + 4], xmm8

    movss xmm7, [rsp+0x08]
    mulss xmm7, xmm0
    movss xmm8, [r15 + E_VEL + 8]
    addss xmm8, xmm7
    movss [r15 + E_VEL + 8], xmm8

.inner_next:
    add  r15, ENTITY_SIZE
    inc  ebp
    jmp  .inner

.outer_next:
    add  r14, ENTITY_SIZE
    inc  r12d
    jmp  .outer

.outer_done:
    add  rsp, 0x40
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbp
    ret
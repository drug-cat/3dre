; ============================================================
; src/scene/entity.asm
; Entity slots + spawn/destroy + gravity + ground + friction
; ============================================================
BITS 64
default rel

%include "entity.inc"

section .data
align 16
gravity:        dd 9.8
ground_y:       dd -4.0             ; top surface of ground plane
restitution:    dd 0.35             ; more realistic than 0.45
min_vy:         dd 0.3
friction:       dd 2.5              ; horizontal damping while grounded (1/s)
f_one:          dd 1.0
abs_mask:       dd 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF
hh_cube:        dd 0.5
hh_sphere:      dd 1.0
hh_pyramid:     dd 0.5

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
;   ecx = type
;   edx = texture id
;   xmm0..xmm2 = position
;   xmm3 = rot_speed
;   xmm4..xmm6 = color
;   xmm7..xmm9 = initial velocity
; Returns: rax = index or -1
; ============================================================
entity_spawn_internal:
    push rbx
    sub  rsp, 0x30

    mov  r8d, ecx                  ; type
    mov  r9d, edx                  ; texture

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

.find:
    cmp  dword [rbx + E_TYPE], E_TYPE_EMPTY
    je   .found
    add  rbx, ENTITY_SIZE
    dec  r10d
    jnz  .find

    mov  rax, -1
    add  rsp, 0x30
    pop  rbx
    ret

.found:
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

    ; ---- half-height per type ----
    cmp  r8d, E_TYPE_SPHERE
    je   .hh_sphere
    ; cube and pyramid → 0.5
    movss xmm0, [hh_cube]
    movss [rbx + E_HALF_H], xmm0
    jmp  .hh_done
.hh_sphere:
    movss xmm0, [hh_sphere]
    movss [rbx + E_HALF_H], xmm0
.hh_done:

    lea  rcx, [entities]
    mov  rax, rbx
    sub  rax, rcx
    shr  rax, 6

    add  rsp, 0x30
    pop  rbx
    ret

; ============================================================
entity_destroy:                    ; ecx = index
    cmp  ecx, MAX_ENTITIES
    jae  .done
    mov  eax, ecx
    shl  eax, 6
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
; ============================================================
; entity_update_all(dt)  ; xmm0 = dt
; ============================================================
entity_update_all:
    push rbx
    push r12
    sub  rsp, 0x28

    movss [rsp], xmm0              ; dt

    ; Load abs_mask once into xmm15 (movups — no alignment required)
    movups xmm15, [abs_mask]

    lea  rbx, [entities]
    mov  r12d, MAX_ENTITIES

.loop:
    cmp  dword [rbx + E_TYPE], E_TYPE_EMPTY
    je   .next

    ; ---- rotation ----
    movss xmm0, [rsp]
    mulss xmm0, [rbx + E_ROT_SPEED]
    addss xmm0, [rbx + E_ROT_Y]
    movss [rbx + E_ROT_Y], xmm0

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

    ; ---- ground collision ----
    movss xmm1, [ground_y]
    addss xmm1, [rbx + E_HALF_H]

    movss xmm0, [rbx + E_POS + 4]
    comiss xmm0, xmm1
    jae  .next

    ; ---- ON GROUND: snap ----
    movss [rbx + E_POS + 4], xmm1

    ; vel.y = -vel.y * restitution
    movss xmm0, [rbx + E_VEL + 4]
    xorps xmm2, xmm2
    subss xmm2, xmm0
    mulss xmm2, [restitution]
    movss [rbx + E_VEL + 4], xmm2

    ; if |vel.y| < min_vy → vel.y = 0
    movaps xmm3, xmm2
    andps  xmm3, xmm15             ; ← use xmm15 (movaps reg-reg is fine)
    movss  xmm4, [min_vy]
    comiss xmm3, xmm4
    jae  .friction
    mov  dword [rbx + E_VEL + 4], 0

.friction:
    ; factor = max(0, 1 - friction * dt)
    movss xmm5, [friction]
    mulss xmm5, [rsp]
    movss xmm6, [f_one]
    subss xmm6, xmm5
    xorps xmm7, xmm7
    maxss xmm6, xmm7

    ; vel.x *= factor
    movss xmm0, [rbx + E_VEL + 0]
    mulss xmm0, xmm6
    movss [rbx + E_VEL + 0], xmm0

    ; vel.z *= factor
    movss xmm0, [rbx + E_VEL + 8]
    mulss xmm0, xmm6
    movss [rbx + E_VEL + 8], xmm0

    ; if |vel.x| and |vel.z| both < min_vy → damp rotation too
    movss xmm0, [rbx + E_VEL + 0]
    andps xmm0, xmm15
    movss xmm1, [min_vy]
    comiss xmm0, xmm1
    jae  .next

    movss xmm0, [rbx + E_VEL + 8]
    andps xmm0, xmm15
    comiss xmm0, xmm1
    jae  .next

    ; rotation speed *= factor
    movss xmm0, [rbx + E_ROT_SPEED]
    mulss xmm0, xmm6
    movss [rbx + E_ROT_SPEED], xmm0

.next:
    add  rbx, ENTITY_SIZE
    dec  r12d
    jnz  .loop

    add  rsp, 0x28
    pop  r12
    pop  rbx
    ret
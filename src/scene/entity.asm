; ============================================================
; src/scene/entity.asm
; Lightweight entity slots with type/position/rotation/color
; ============================================================
BITS 64
default rel

%include "entity.inc"

section .bss
align 16
global entities
entities:       resb MAX_ENTITIES * ENTITY_SIZE

section .text
global entity_init
global entity_spawn_cube
global entity_spawn_sphere
global entity_destroy
global entity_update_all

; ============================================================
; entity_init() — mark every slot as empty
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
; entity_spawn_cube(x, y, z, rot_speed, r, g, b) → rax = index or -1
;   xmm0..xmm2 = position
;   xmm3       = rotation speed (rad/s)
;   xmm4..xmm6 = color tint (r, g, b)
; ============================================================
entity_spawn_cube:
    mov  ecx, E_TYPE_CUBE
    jmp  entity_spawn_internal

; ============================================================
; entity_spawn_sphere(x, y, z, rot_speed, r, g, b) → rax
; ============================================================
entity_spawn_sphere:
    mov  ecx, E_TYPE_SPHERE
    jmp  entity_spawn_internal

; ============================================================
; entity_spawn_internal:
;   ecx = type
;   xmm0..xmm2 = position
;   xmm3       = rot_speed
;   xmm4..xmm6 = color
; Returns: rax = index, or -1 if table is full
; ============================================================
entity_spawn_internal:
    push rbx
    sub  rsp, 0x20

    lea  rbx, [entities]
    mov  r8d, MAX_ENTITIES

.find:
    cmp  dword [rbx + E_TYPE], E_TYPE_EMPTY
    je   .found
    add  rbx, ENTITY_SIZE
    dec  r8d
    jnz  .find

    mov  rax, -1
    add  rsp, 0x20
    pop  rbx
    ret

.found:
    mov  dword [rbx + E_TYPE], ecx
    mov  dword [rbx + E_FLAGS], 0

    movss [rbx + E_POS + 0], xmm0
    movss [rbx + E_POS + 4], xmm1
    movss [rbx + E_POS + 8], xmm2

    xorps xmm7, xmm7
    movss [rbx + E_ROT_Y], xmm7
    movss [rbx + E_ROT_SPEED], xmm3

    mov  eax, 0x3F800000           ; 1.0f
    mov  dword [rbx + E_SCALE], eax

    movss [rbx + E_COLOR + 0], xmm4
    movss [rbx + E_COLOR + 4], xmm5
    movss [rbx + E_COLOR + 8], xmm6
    mov  dword [rbx + E_PAD0], 0

    mov  dword [rbx + E_VEL + 0], 0
    mov  dword [rbx + E_VEL + 4], 0
    mov  dword [rbx + E_VEL + 8], 0
    mov  dword [rbx + E_PAD1], 0

    ; index = (rbx - &entities) >> 6   (ENTITY_SIZE = 64)
    lea  rcx, [entities]
    mov  rax, rbx
    sub  rax, rcx
    shr  rax, 6

    add  rsp, 0x20
    pop  rbx
    ret

; ============================================================
; entity_destroy(index)  — ecx = index
; ============================================================
entity_destroy:
    cmp  ecx, MAX_ENTITIES
    jae  .done
    mov  eax, ecx
    shl  eax, 6                    ; * 64
    lea  rdx, [entities]
    add  rdx, rax
    mov  dword [rdx + E_TYPE], E_TYPE_EMPTY
.done:
    ret

; ============================================================
; entity_update_all(dt)  — xmm0 = dt
;   Advances rot_y by dt * rot_speed for each live entity
; ============================================================
entity_update_all:
    push rbx
    sub  rsp, 0x20
    movss [rsp], xmm0

    lea  rbx, [entities]
    mov  ecx, MAX_ENTITIES

.loop:
    cmp  dword [rbx + E_TYPE], E_TYPE_EMPTY
    je   .next

    movss xmm0, [rsp]
    mulss xmm0, [rbx + E_ROT_SPEED]
    addss xmm0, [rbx + E_ROT_Y]
    movss [rbx + E_ROT_Y], xmm0

.next:
    add  rbx, ENTITY_SIZE
    dec  ecx
    jnz  .loop

    add  rsp, 0x20
    pop  rbx
    ret
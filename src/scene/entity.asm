; ============================================================
; src/scene/entity.asm
; Lightweight entity slots with type/position/rotation/texture
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
global entity_spawn_pyramid
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
;   xmm3       = rotation speed
;   xmm4..xmm6 = color tint
;   edx        = GL texture id (0 = none)
; ============================================================
entity_spawn_cube:
    mov  ecx, E_TYPE_CUBE
    jmp  entity_spawn_internal

; ============================================================
entity_spawn_sphere:
    mov  ecx, E_TYPE_SPHERE
    jmp  entity_spawn_internal

; ============================================================
entity_spawn_pyramid:
    mov  ecx, E_TYPE_PYRAMID
    jmp  entity_spawn_internal

; ============================================================
; entity_spawn_internal:
;   ecx = type
;   edx = texture id (0 = none)
;   xmm0..xmm2 = position
;   xmm3       = rot_speed
;   xmm4..xmm6 = color
; Returns: rax = index, or -1 if table is full
; ============================================================
entity_spawn_internal:
    push rbx
    sub  rsp, 0x20

    ; save type and texture across the loop
    mov  r8d, ecx                  ; type
    mov  r9d, edx                  ; texture id

    lea  rbx, [entities]
    mov  r10d, MAX_ENTITIES

.find:
    cmp  dword [rbx + E_TYPE], E_TYPE_EMPTY
    je   .found
    add  rbx, ENTITY_SIZE
    dec  r10d
    jnz  .find

    mov  rax, -1
    add  rsp, 0x20
    pop  rbx
    ret

.found:
    ; ---- type / flags ----
    mov  dword [rbx + E_TYPE], r8d
    mov  dword [rbx + E_FLAGS], 0

    ; ---- position ----
    movss [rbx + E_POS + 0], xmm0
    movss [rbx + E_POS + 4], xmm1
    movss [rbx + E_POS + 8], xmm2

    ; ---- rotation ----
    xorps xmm7, xmm7
    movss [rbx + E_ROT_Y], xmm7
    movss [rbx + E_ROT_SPEED], xmm3

    ; ---- scale = 1.0 ----
    mov  eax, 0x3F800000
    mov  dword [rbx + E_SCALE], eax

    ; ---- color ----
    movss [rbx + E_COLOR + 0], xmm4
    movss [rbx + E_COLOR + 4], xmm5
    movss [rbx + E_COLOR + 8], xmm6

    ; ---- texture ----
    mov  dword [rbx + E_TEXTURE], r9d

    ; ---- velocity = 0 ----
    mov  dword [rbx + E_VEL + 0], 0
    mov  dword [rbx + E_VEL + 4], 0
    mov  dword [rbx + E_VEL + 8], 0
    mov  dword [rbx + E_PAD1], 0

    ; ---- compute index ----
    lea  rcx, [entities]
    mov  rax, rbx
    sub  rax, rcx
    shr  rax, 6                    ; / 64

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
    shl  eax, 6
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
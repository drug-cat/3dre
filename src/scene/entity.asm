; ============================================================
; src/scene/entity.asm
; Entity slots + spawn/destroy helpers
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
; entity_spawn_internal:
;   ecx = type
;   edx = texture id (0 = none)
;   xmm0..xmm2 = position
;   xmm3 = rot_speed
;   xmm4..xmm6 = color
; Returns: rax = index, or -1 if table full
; ============================================================
entity_spawn_internal:
    push rbx
    sub  rsp, 0x20

    ; stash args
    mov  r8d, ecx                  ; type
    mov  r9d, edx                  ; texture

    movss [rsp+0x00], xmm0         ; x
    movss [rsp+0x04], xmm1         ; y
    movss [rsp+0x08], xmm2         ; z
    movss [rsp+0x0C], xmm3         ; rot_speed
    movss [rsp+0x10], xmm4         ; r
    movss [rsp+0x14], xmm5         ; g
    movss [rsp+0x18], xmm6         ; b

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

    mov  eax, 0x3F800000           ; 1.0f
    mov  dword [rbx + E_SCALE], eax

    movss xmm0, [rsp+0x10]
    movss [rbx + E_COLOR + 0], xmm0
    movss xmm0, [rsp+0x14]
    movss [rbx + E_COLOR + 4], xmm0
    movss xmm0, [rsp+0x18]
    movss [rbx + E_COLOR + 8], xmm0

    mov  dword [rbx + E_TEXTURE], r9d

    mov  dword [rbx + E_VEL + 0], 0
    mov  dword [rbx + E_VEL + 4], 0
    mov  dword [rbx + E_VEL + 8], 0
    mov  dword [rbx + E_PAD1], 0

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
    shl  eax, 6
    lea  rdx, [entities]
    add  rdx, rax
    mov  dword [rdx + E_TYPE], E_TYPE_EMPTY
.done:
    ret

; ============================================================
; entity_destroy_last() — remove the highest-index live entity
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
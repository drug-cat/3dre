; ============================================================
; src/platform/input.asm
; Keyboard + mouse-look state
; ============================================================
BITS 64
default rel

%include "input.inc"

extern GetCursorPos
extern SetCursorPos
extern ShowCursor
extern GetClientRect
extern ClientToScreen

section .bss
align 16
keys_down:              resb 256
keys_pressed:           resb 256
keys_released:          resb 256

align 4
mouse_delta_x:          resd 1
mouse_delta_y:          resd 1
mouse_center_screen_x:  resd 1
mouse_center_screen_y:  resd 1
mouse_hwnd:             resq 1
mouse_active:           resd 1
cursor_hidden:          resd 1

section .text
global input_init
global input_on_key_down
global input_on_key_up
global input_end_frame
global input_is_down
global input_is_pressed
global input_is_released

global input_enable_mouse_look
global input_disable_mouse_look
global input_poll_mouse
global input_mouse_is_active
global mouse_delta_x
global mouse_delta_y

; ============================================================
input_init:
    push rdi
    lea  rdi, [keys_down]
    xor  eax, eax
    mov  ecx, 256
    rep stosb
    lea  rdi, [keys_pressed]
    mov  ecx, 256
    rep stosb
    lea  rdi, [keys_released]
    mov  ecx, 256
    rep stosb
    mov  dword [mouse_active], 0
    mov  dword [cursor_hidden], 0
    mov  dword [mouse_delta_x], 0
    mov  dword [mouse_delta_y], 0
    pop  rdi
    ret

; ============================================================
input_on_key_down:
    cmp  ecx, 256
    jae  .done
    movzx eax, cl
    lea  r8, [keys_down]
    test rdx, KEY_REPEAT_FLAG
    jnz  .set_down_only
    lea  r9, [keys_pressed]
    mov  byte [r9 + rax], 1
.set_down_only:
    mov  byte [r8 + rax], 1
.done:
    ret

; ============================================================
input_on_key_up:
    cmp  ecx, 256
    jae  .done
    movzx eax, cl
    lea  r8, [keys_down]
    mov  byte [r8 + rax], 0
    lea  r9, [keys_released]
    mov  byte [r9 + rax], 1
.done:
    ret

; ============================================================
input_end_frame:
    push rdi
    lea  rdi, [keys_pressed]
    mov  ecx, 256
    xor  eax, eax
    rep stosb
    lea  rdi, [keys_released]
    mov  ecx, 256
    xor  eax, eax
    rep stosb
    pop  rdi
    ret

; ============================================================
input_is_down:
    cmp  ecx, 256
    jae  .no
    movzx eax, cl
    lea  r8, [keys_down]
    movzx eax, byte [r8 + rax]
    ret
.no:
    xor  eax, eax
    ret

; ============================================================
input_is_pressed:
    cmp  ecx, 256
    jae  .no
    movzx eax, cl
    lea  r8, [keys_pressed]
    movzx eax, byte [r8 + rax]
    ret
.no:
    xor  eax, eax
    ret

; ============================================================
input_is_released:
    cmp  ecx, 256
    jae  .no
    movzx eax, cl
    lea  r8, [keys_released]
    movzx eax, byte [r8 + rax]
    ret
.no:
    xor  eax, eax
    ret

; ============================================================
input_mouse_is_active:
    mov  eax, [mouse_active]
    ret

; ============================================================
; input_enable_mouse_look(hwnd)
;   rcx = hwnd
;   Call when window gains focus.
; ============================================================
input_enable_mouse_look:
    push rbx
    sub  rsp, 0x40
    mov  rbx, rcx
    mov  [mouse_hwnd], rbx

    ; GetClientRect(hwnd, &rect)
    mov  rcx, rbx
    lea  rdx, [rsp]
    call GetClientRect

    ; Center in client coords
    mov  eax, [rsp+8]              ; rect.right
    shr  eax, 1
    mov  [rsp+16], eax
    mov  eax, [rsp+12]             ; rect.bottom
    shr  eax, 1
    mov  [rsp+20], eax

    ; ClientToScreen
    mov  rcx, rbx
    lea  rdx, [rsp+16]
    call ClientToScreen

    mov  eax, [rsp+16]
    mov  [mouse_center_screen_x], eax
    mov  eax, [rsp+20]
    mov  [mouse_center_screen_y], eax

    ; Warp cursor to center
    mov  ecx, [mouse_center_screen_x]
    mov  edx, [mouse_center_screen_y]
    call SetCursorPos

    ; Hide cursor (loop until counter is negative)
    cmp  dword [cursor_hidden], 0
    jne  .already_hidden
.hide_loop:
    mov  ecx, 0
    call ShowCursor
    test eax, eax
    jns  .hide_loop
    mov  dword [cursor_hidden], 1
.already_hidden:

    mov  dword [mouse_active], 1
    mov  dword [mouse_delta_x], 0
    mov  dword [mouse_delta_y], 0

    add  rsp, 0x40
    pop  rbx
    ret

; ============================================================
; input_disable_mouse_look()
;   Call when window loses focus.
; ============================================================
input_disable_mouse_look:
    sub  rsp, 0x28
    mov  dword [mouse_active], 0

    cmp  dword [cursor_hidden], 0
    je   .already_shown
.show_loop:
    mov  ecx, 1
    call ShowCursor
    test eax, eax
    js   .show_loop
    mov  dword [cursor_hidden], 0
.already_shown:

    add  rsp, 0x28
    ret

; ============================================================
; input_poll_mouse — call once per frame
; ============================================================
input_poll_mouse:
    sub  rsp, 0x28
    cmp  dword [mouse_active], 0
    je   .zero

    lea  rcx, [rsp+8]
    call GetCursorPos

    mov  eax, [rsp+8]
    sub  eax, [mouse_center_screen_x]
    mov  [mouse_delta_x], eax

    mov  eax, [rsp+12]
    sub  eax, [mouse_center_screen_y]
    mov  [mouse_delta_y], eax

    cmp  dword [mouse_delta_x], 0
    jne  .warp
    cmp  dword [mouse_delta_y], 0
    jne  .warp
    jmp  .done

.warp:
    mov  ecx, [mouse_center_screen_x]
    mov  edx, [mouse_center_screen_y]
    call SetCursorPos
    jmp  .done

.zero:
    mov  dword [mouse_delta_x], 0
    mov  dword [mouse_delta_y], 0
.done:
    add  rsp, 0x28
    ret
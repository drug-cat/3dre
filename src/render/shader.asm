; ============================================================
; src/render/shader.asm
; File-based shader programs with error reporting + hot reload
; ============================================================
BITS 64
default rel

%include "gl.inc"
%include "shader.inc"

; ---- GL 3.3 pointers (from gl_loader.asm) ----
extern glCreateShader
extern glShaderSource
extern glCompileShader
extern glGetShaderiv
extern glGetShaderInfoLog
extern glDeleteShader
extern glCreateProgram
extern glAttachShader
extern glLinkProgram
extern glGetProgramiv
extern glGetProgramInfoLog
extern glUseProgram
extern glDeleteProgram
extern glGetUniformLocation
extern glUniformMatrix4fv
extern glUniform1f
extern glUniform3f

; ---- file.asm ----
extern file_read
extern file_free
extern file_write_time
extern str_dup
extern str_free

; ---- Win32 ----
extern MessageBoxA
extern wsprintfA

section .data
align 16
fmt_error     db "Shader failed:",13,10,13,10,"%s",13,10,13,10,"%s",0
msgbox_title  db "3dre - Shader Error",0
str_prog_bad  db "(program link)",0

section .text
global shader_program_init
global shader_program_hot_reload
global shader_program_use
global shader_program_destroy
global shader_set_mat4
global shader_set_float
global shader_set_vec3

; ============================================================
; shader_show_error
;   rcx = path (may be 0)
;   rdx = log text (may be 0)
; ============================================================
shader_show_error:
    push rbx
    push rsi
    sub  rsp, 0x818

    mov  rbx, rcx
    mov  rsi, rdx

    test rbx, rbx
    jnz  .have_path
    lea  rbx, [str_prog_bad]
.have_path:
    test rsi, rsi
    jnz  .have_log
    lea  rsi, [str_prog_bad]
.have_log:

    lea  rcx, [rsp]
    lea  rdx, [fmt_error]
    mov  r8,  rbx
    mov  r9,  rsi
    call wsprintfA

    xor  ecx, ecx
    lea  rdx, [rsp]
    lea  r8,  [msgbox_title]
    mov  r9d, 0x10                 ; MB_ICONERROR
    call MessageBoxA

    add  rsp, 0x818
    pop  rsi
    pop  rbx
    ret

; ============================================================
; shader_compile
;   rcx = source string (null-terminated)
;   edx = GL_VERTEX_SHADER or GL_FRAGMENT_SHADER
;   r8  = path (for error msg)
; Returns eax = shader id, 0 on fail (shows MessageBox on fail)
; ============================================================
shader_compile:
    push rbx
    push rsi
    push rdi
    sub  rsp, 0x830

    mov  rbx, rcx                  ; src
    mov  rsi, r8                   ; path
    mov  edi, edx                  ; type (save before any calls)

    ; --- Create shader ---
    mov  ecx, edi
    call qword [glCreateShader]
    test eax, eax
    jz   .fail
    mov  edi, eax                  ; edi = shader id

    ; --- shaderSource(id, 1, &src, 0) ---
    mov  [rsp+0x10], rbx           ; pointer to source
    mov  rcx, rdi
    mov  edx, 1
    lea  r8,  [rsp+0x10]
    xor  r9d, r9d
    call qword [glShaderSource]

    ; --- compile ---
    mov  rcx, rdi
    call qword [glCompileShader]

    ; --- check status ---
    mov  rcx, rdi
    mov  edx, GL_COMPILE_STATUS
    lea  r8,  [rsp+0x08]
    call qword [glGetShaderiv]
    mov  eax, [rsp+0x08]
    test eax, eax
    jnz  .ok

    ; --- compile failed: fetch log ---
    mov  rcx, rdi
    mov  edx, GL_INFO_LOG_LENGTH
    lea  r8,  [rsp+0x0C]
    call qword [glGetShaderiv]
    mov  eax, [rsp+0x0C]
    test eax, eax
    jz   .show_no_log

    cmp  eax, 2048
    jbe  .log_len_ok
    mov  eax, 2048
.log_len_ok:
    mov  [rsp+0x18], eax           ; clamp length

    mov  rcx, rdi
    mov  edx, eax
    lea  r8,  [rsp+0x20]
    xor  r9d, r9d
    call qword [glGetShaderInfoLog]

    mov  eax, [rsp+0x18]
    dec  eax
    mov  byte [rsp+0x20+rax], 0

    mov  rcx, rsi
    lea  rdx, [rsp+0x20]
    call shader_show_error

    jmp  .cleanup

.show_no_log:
    mov  rcx, rsi
    xor  edx, edx
    call shader_show_error

.cleanup:
    mov  rcx, rdi
    call qword [glDeleteShader]
.fail:
    xor  eax, eax
    add  rsp, 0x830
    pop  rdi
    pop  rsi
    pop  rbx
    ret

.ok:
    mov  eax, edi
    add  rsp, 0x830
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
; shader_link
;   ecx = vertex shader id
;   edx = fragment shader id
; Returns eax = program id, 0 on fail
; ============================================================
shader_link:
    push rbx
    push rsi
    push rdi
    sub  rsp, 0x820

    mov  ebx, ecx                  ; vs
    mov  esi, edx                  ; fs

    call qword [glCreateProgram]
    test eax, eax
    jz   .fail
    mov  edi, eax

    mov  rcx, rdi
    mov  edx, ebx
    call qword [glAttachShader]
    mov  rcx, rdi
    mov  edx, esi
    call qword [glAttachShader]

    mov  rcx, rdi
    call qword [glLinkProgram]

    mov  rcx, rdi
    mov  edx, GL_LINK_STATUS
    lea  r8,  [rsp+0x08]
    call qword [glGetProgramiv]
    mov  eax, [rsp+0x08]
    test eax, eax
    jnz  .ok

    ; --- link failed ---
    mov  rcx, rdi
    mov  edx, GL_INFO_LOG_LENGTH
    lea  r8,  [rsp+0x0C]
    call qword [glGetProgramiv]
    mov  eax, [rsp+0x0C]
    test eax, eax
    jz   .show_no_log

    cmp  eax, 2048
    jbe  .log_len_ok
    mov  eax, 2048
.log_len_ok:
    mov  [rsp+0x18], eax

    mov  rcx, rdi
    mov  edx, eax
    lea  r8,  [rsp+0x20]
    xor  r9d, r9d
    call qword [glGetProgramInfoLog]

    mov  eax, [rsp+0x18]
    dec  eax
    mov  byte [rsp+0x20+rax], 0

    xor  ecx, ecx
    lea  rdx, [rsp+0x20]
    call shader_show_error
    jmp  .cleanup

.show_no_log:
    xor  ecx, ecx
    xor  edx, edx
    call shader_show_error

.cleanup:
    mov  rcx, rdi
    call qword [glDeleteProgram]
.fail:
    xor  eax, eax
    add  rsp, 0x820
    pop  rdi
    pop  rsi
    pop  rbx
    ret

.ok:
    mov  eax, edi
    add  rsp, 0x820
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
; shader_reload_pass
;   rcx = ShaderProgram*
; Returns eax = 1 / 0
; ============================================================
shader_reload_pass:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    sub  rsp, 0x28

    mov  rbx, rcx

    ; --- read vertex source ---
    mov  rcx, [rbx+SP_VS_PATH]
    call file_read
    test rax, rax
    jz   .fail
    mov  r12, rax

    ; --- read fragment source ---
    mov  rcx, [rbx+SP_FS_PATH]
    call file_read
    test rax, rax
    jz   .fail_no_shaders
    mov  r13, rax

    ; --- compile vertex ---
    mov  rcx, r12
    mov  edx, GL_VERTEX_SHADER
    mov  r8,  [rbx+SP_VS_PATH]
    call shader_compile
    test eax, eax
    jz   .fail_no_shaders
    mov  edi, eax

    ; --- compile fragment ---
    mov  rcx, r13
    mov  edx, GL_FRAGMENT_SHADER
    mov  r8,  [rbx+SP_FS_PATH]
    call shader_compile
    test eax, eax
    jz   .fail_vs_only
    mov  esi, eax

    ; --- link ---
    mov  rcx, rdi
    mov  rdx, rsi
    call shader_link
    test eax, eax
    jz   .fail_both_shaders
    mov  r14d, eax                 ; new program id

    ; --- delete old program ---
    mov  eax, [rbx+SP_ID]
    test eax, eax
    jz   .no_old
    mov  ecx, eax
    call qword [glDeleteProgram]
.no_old:
    mov  [rbx+SP_ID], r14d

    ; --- delete shaders (already attached to program) ---
    mov  rcx, rdi
    call qword [glDeleteShader]
    mov  rcx, rsi
    call qword [glDeleteShader]

    ; --- update write times ---
    mov  rcx, [rbx+SP_VS_PATH]
    call file_write_time
    mov  [rbx+SP_VS_WTIME], rax
    mov  rcx, [rbx+SP_FS_PATH]
    call file_write_time
    mov  [rbx+SP_FS_WTIME], rax

    ; --- free source buffers ---
    mov  rcx, r13
    call file_free
    mov  rcx, r12
    call file_free

    mov  eax, 1
    jmp  .done

.fail_both_shaders:
    mov  rcx, rdi
    call qword [glDeleteShader]
    mov  rcx, rsi
    call qword [glDeleteShader]
    jmp  .fail_vs_only

.fail_vs_only:
    mov  rcx, rdi
    call qword [glDeleteShader]
    jmp  .fail_no_shaders

.fail_no_shaders:
    mov  rcx, r13
    call file_free
    mov  rcx, r12
    call file_free
.fail:
    xor  eax, eax

.done:
    add  rsp, 0x28
    pop  r14
    pop  r13
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
; shader_program_init(ShaderProgram* sp, const char* vs, const char* fs)
; ============================================================
shader_program_init:
    push rbx
    push rsi
    push rdi
    sub  rsp, 0x30

    mov  rbx, rcx
    mov  rsi, rdx
    mov  rdi, r8

    ; zero struct
    pxor xmm0, xmm0
    movdqu [rbx],    xmm0
    movdqu [rbx+16], xmm0
    movdqu [rbx+32], xmm0
    movdqu [rbx+48], xmm0

    ; dup vertex path
    mov  rcx, rsi
    call str_dup
    test rax, rax
    jz   .fail
    mov  [rbx+SP_VS_PATH], rax

    ; dup fragment path
    mov  rcx, rdi
    call str_dup
    test rax, rax
    jz   .fail_free_vs
    mov  [rbx+SP_FS_PATH], rax

    ; compile + link
    mov  rcx, rbx
    call shader_reload_pass
    test eax, eax
    jz   .fail_free_both

    mov  eax, 1
    add  rsp, 0x30
    pop  rdi
    pop  rsi
    pop  rbx
    ret

.fail_free_both:
    mov  rcx, [rbx+SP_FS_PATH]
    call str_free
    mov  qword [rbx+SP_FS_PATH], 0
.fail_free_vs:
    mov  rcx, [rbx+SP_VS_PATH]
    call str_free
    mov  qword [rbx+SP_VS_PATH], 0
.fail:
    xor  eax, eax
    add  rsp, 0x30
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
; shader_program_hot_reload(ShaderProgram* sp) -> eax = 1 if reloaded OK
; ============================================================
shader_program_hot_reload:
    push rbx
    sub  rsp, 0x20

    mov  rbx, rcx

    cmp  qword [rbx+SP_VS_PATH], 0
    je   .no
    cmp  qword [rbx+SP_FS_PATH], 0
    je   .no
    cmp  dword [rbx+SP_ID], 0
    je   .no

    ; check vertex mtime
    mov  rcx, [rbx+SP_VS_PATH]
    call file_write_time
    test rax, rax
    jz   .no
    cmp  rax, [rbx+SP_VS_WTIME]
    jne  .changed

    ; check fragment mtime
    mov  rcx, [rbx+SP_FS_PATH]
    call file_write_time
    test rax, rax
    jz   .no
    cmp  rax, [rbx+SP_FS_WTIME]
    jne  .changed

.no:
    xor  eax, eax
    add  rsp, 0x20
    pop  rbx
    ret

.changed:
    mov  rcx, rbx
    call shader_reload_pass
    add  rsp, 0x20
    pop  rbx
    ret

; ============================================================
shader_program_use:                 ; rcx = sp
    mov  ecx, [rcx+SP_ID]
    test ecx, ecx
    jz   .skip
    jmp  qword [glUseProgram]
.skip:
    ret

; ============================================================
shader_program_destroy:             ; rcx = sp
    push rbx
    sub  rsp, 0x20
    mov  rbx, rcx

    mov  eax, [rbx+SP_ID]
    test eax, eax
    jz   .no_prog
    mov  ecx, eax
    call qword [glDeleteProgram]
    mov  dword [rbx+SP_ID], 0
.no_prog:
    mov  rcx, [rbx+SP_VS_PATH]
    test rcx, rcx
    jz   .no_vs
    call str_free
    mov  qword [rbx+SP_VS_PATH], 0
.no_vs:
    mov  rcx, [rbx+SP_FS_PATH]
    test rcx, rcx
    jz   .done
    call str_free
    mov  qword [rbx+SP_FS_PATH], 0
.done:
    add  rsp, 0x20
    pop  rbx
    ret

; ============================================================
; shader_set_mat4(sp, name, const float* mat)
;   rcx = sp, rdx = name, r8 = mat
; ============================================================
shader_set_mat4:
    push rbx
    sub  rsp, 0x20
    mov  rbx, r8                   ; mat
    mov  ecx, [rcx+SP_ID]
    test ecx, ecx
    jz   .done
    call qword [glGetUniformLocation]
    cmp  eax, -1
    je   .done
    mov  ecx, eax
    mov  edx, 1
    xor  r8d, r8d
    mov  r9,  rbx
    call qword [glUniformMatrix4fv]
.done:
    add  rsp, 0x20
    pop  rbx
    ret

; ============================================================
; shader_set_float(sp, name, float v)
;   rcx = sp, rdx = name, xmm2 = v
; ============================================================
shader_set_float:
    push rbx
    sub  rsp, 0x20
    movss [rsp], xmm2
    mov  rbx, rdx
    mov  ecx, [rcx+SP_ID]
    test ecx, ecx
    jz   .done
    mov  rdx, rbx
    call qword [glGetUniformLocation]
    cmp  eax, -1
    je   .done
    mov  ecx, eax
    movss xmm0, [rsp]
    call qword [glUniform1f]
.done:
    add  rsp, 0x20
    pop  rbx
    ret

; ============================================================
; shader_set_vec3(sp, name, const float* v)
;   rcx = sp, rdx = name, r8 = v
; ============================================================
shader_set_vec3:
    push rbx
    sub  rsp, 0x20
    mov  rbx, r8
    mov  ecx, [rcx+SP_ID]
    test ecx, ecx
    jz   .done
    call qword [glGetUniformLocation]
    cmp  eax, -1
    je   .done
    mov  ecx, eax
    movss xmm0, [rbx]
    movss xmm1, [rbx+4]
    movss xmm2, [rbx+8]
    call qword [glUniform3f]
.done:
    add  rsp, 0x20
    pop  rbx
    ret
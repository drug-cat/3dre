; ============================================================
; src/render/gl_loader.asm
; Load OpenGL 3.3 function pointers via wglGetProcAddress
; ============================================================
BITS 64
default rel

%include "gl.inc"

extern wglGetProcAddress

; ============================================================
section .bss
align 8

; ---- Shader functions ----
global glCreateShader
global glShaderSource
global glCompileShader
global glGetShaderiv
global glGetShaderInfoLog
global glDeleteShader

; ---- Program functions ----
global glCreateProgram
global glAttachShader
global glLinkProgram
global glGetProgramiv
global glGetProgramInfoLog
global glUseProgram
global glDeleteProgram

; ---- Uniform functions ----
global glGetUniformLocation
global glUniformMatrix4fv
global glUniform1f
global glUniform3f
global glUniform4f

; ---- VAO / VBO / EBO ----
global glGenVertexArrays
global glBindVertexArray
global glDeleteVertexArrays
global glGenBuffers
global glBindBuffer
global glBufferData
global glDeleteBuffers

; ---- Vertex attributes ----
global glVertexAttribPointer
global glEnableVertexAttribArray
global glDisableVertexAttribArray

; ---- Draw calls ----
global glDrawArrays
global glDrawElements

glCreateShader            resq 1
glShaderSource            resq 1
glCompileShader           resq 1
glGetShaderiv             resq 1
glGetShaderInfoLog        resq 1
glDeleteShader            resq 1

glCreateProgram           resq 1
glAttachShader            resq 1
glLinkProgram             resq 1
glGetProgramiv            resq 1
glGetProgramInfoLog       resq 1
glUseProgram              resq 1
glDeleteProgram           resq 1

glGetUniformLocation      resq 1
glUniformMatrix4fv        resq 1
glUniform1f               resq 1
glUniform3f               resq 1
glUniform4f               resq 1

glGenVertexArrays         resq 1
glBindVertexArray         resq 1
glDeleteVertexArrays      resq 1
glGenBuffers              resq 1
glBindBuffer              resq 1
glBufferData              resq 1
glDeleteBuffers           resq 1

glVertexAttribPointer     resq 1
glEnableVertexAttribArray resq 1
glDisableVertexAttribArray resq 1

glDrawArrays              resq 1
glDrawElements            resq 1

; ============================================================
section .rodata
n_CreateShader            db "glCreateShader",0
n_ShaderSource            db "glShaderSource",0
n_CompileShader           db "glCompileShader",0
n_GetShaderiv             db "glGetShaderiv",0
n_GetShaderInfoLog        db "glGetShaderInfoLog",0
n_DeleteShader            db "glDeleteShader",0

n_CreateProgram           db "glCreateProgram",0
n_AttachShader            db "glAttachShader",0
n_LinkProgram             db "glLinkProgram",0
n_GetProgramiv            db "glGetProgramiv",0
n_GetProgramInfoLog       db "glGetProgramInfoLog",0
n_UseProgram              db "glUseProgram",0
n_DeleteProgram           db "glDeleteProgram",0

n_GetUniformLocation      db "glGetUniformLocation",0
n_UniformMatrix4fv        db "glUniformMatrix4fv",0
n_Uniform1f               db "glUniform1f",0
n_Uniform3f               db "glUniform3f",0
n_Uniform4f               db "glUniform4f",0

n_GenVertexArrays         db "glGenVertexArrays",0
n_BindVertexArray         db "glBindVertexArray",0
n_DeleteVertexArrays      db "glDeleteVertexArrays",0
n_GenBuffers              db "glGenBuffers",0
n_BindBuffer              db "glBindBuffer",0
n_BufferData              db "glBufferData",0
n_DeleteBuffers           db "glDeleteBuffers",0

n_VertexAttribPointer     db "glVertexAttribPointer",0
n_EnableVertexAttribArray db "glEnableVertexAttribArray",0
n_DisableVertexAttribArray db "glDisableVertexAttribArray",0

n_DrawArrays              db "glDrawArrays",0
n_DrawElements            db "glDrawElements",0

align 8
; ---- Table of { name_ptr, storage_ptr } ----
func_table:
    dq n_CreateShader,            glCreateShader
    dq n_ShaderSource,            glShaderSource
    dq n_CompileShader,           glCompileShader
    dq n_GetShaderiv,             glGetShaderiv
    dq n_GetShaderInfoLog,        glGetShaderInfoLog
    dq n_DeleteShader,            glDeleteShader

    dq n_CreateProgram,           glCreateProgram
    dq n_AttachShader,            glAttachShader
    dq n_LinkProgram,             glLinkProgram
    dq n_GetProgramiv,            glGetProgramiv
    dq n_GetProgramInfoLog,       glGetProgramInfoLog
    dq n_UseProgram,              glUseProgram
    dq n_DeleteProgram,           glDeleteProgram

    dq n_GetUniformLocation,      glGetUniformLocation
    dq n_UniformMatrix4fv,        glUniformMatrix4fv
    dq n_Uniform1f,               glUniform1f
    dq n_Uniform3f,               glUniform3f
    dq n_Uniform4f,               glUniform4f

    dq n_GenVertexArrays,         glGenVertexArrays
    dq n_BindVertexArray,         glBindVertexArray
    dq n_DeleteVertexArrays,      glDeleteVertexArrays
    dq n_GenBuffers,              glGenBuffers
    dq n_BindBuffer,              glBindBuffer
    dq n_BufferData,              glBufferData
    dq n_DeleteBuffers,           glDeleteBuffers

    dq n_VertexAttribPointer,     glVertexAttribPointer
    dq n_EnableVertexAttribArray, glEnableVertexAttribArray
    dq n_DisableVertexAttribArray, glDisableVertexAttribArray

    dq n_DrawArrays,              glDrawArrays
    dq n_DrawElements,            glDrawElements

    dq 0, 0                       ; terminator

; ============================================================
section .text

; ============================================================
; gl_load_functions
; Loads every function pointer via wglGetProcAddress.
; Returns: eax = 1 on success, 0 on failure
; ============================================================
global gl_load_functions
gl_load_functions:
    push rbx
    push rsi
    sub  rsp, 0x20

    lea  rbx, [func_table]
.loop:
    mov  rsi, [rbx]                ; rsi = name ptr
    test rsi, rsi
    jz   .success

    mov  rcx, rsi
    call wglGetProcAddress
    test rax, rax
    jz   .fail

    mov  rdx, [rbx+8]              ; &storage
    mov  [rdx], rax
    add  rbx, 16
    jmp  .loop

.success:
    mov  eax, 1
    add  rsp, 0x20
    pop  rsi
    pop  rbx
    ret

.fail:
    xor  eax, eax
    add  rsp, 0x20
    pop  rsi
    pop  rbx
    ret
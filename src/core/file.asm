; ============================================================
; src/core/file.asm
; File I/O + path helpers (Win32, uses LocalAlloc/LocalFree)
; ============================================================
BITS 64
default rel

extern CreateFileA
extern ReadFile
extern WriteFile
extern GetFileSizeEx
extern CloseHandle
extern GetFileAttributesExA
extern GetModuleFileNameA
extern LocalAlloc
extern LocalFree

section .text
global file_read
global file_write
global file_free
global file_write_time
global file_get_exe_dir
global path_join_exe
global str_dup
global str_free

; ============================================================
; file_read(const char* path) → rax = null-terminated buffer, 0 on fail
; ============================================================
file_read:
    push rbx
    push rsi
    push rdi
    push r12
    sub  rsp, 0x48

    mov  qword [rsp+0x38], 0
    mov  dword [rsp+0x40], 0

    mov  rbx, rcx

    mov  rcx, rbx
    mov  edx, 0x80000000
    mov  r8d, 1
    xor  r9d, r9d
    mov  qword [rsp+0x20], 3
    mov  qword [rsp+0x28], 0x80
    mov  qword [rsp+0x30], 0
    call CreateFileA
    cmp  rax, -1
    je   .fail
    test rax, rax
    jz   .fail
    mov  r12, rax

    mov  rcx, r12
    lea  rdx, [rsp+0x38]
    call GetFileSizeEx
    test eax, eax
    jz   .fail_close
    mov  rdi, [rsp+0x38]

    cmp  rdi, 1
    jae  .size_min_ok
    mov  rdi, 1
.size_min_ok:
    cmp  rdi, 0x1000000
    ja   .fail_close

    xor  ecx, ecx
    lea  rdx, [rdi+1]
    call LocalAlloc
    test rax, rax
    jz   .fail_close
    mov  rsi, rax

    mov  rcx, r12
    mov  rdx, rsi
    mov  r8,  rdi
    lea  r9,  [rsp+0x40]
    mov  qword [rsp+0x20], 0
    call ReadFile
    test eax, eax
    jz   .fail_free

    mov  eax, [rsp+0x40]
    cmp  eax, edi
    jbe  .term_ok
    mov  eax, edi
.term_ok:
    mov  byte [rsi+rax], 0

    mov  rcx, r12
    call CloseHandle

    mov  rax, rsi
    add  rsp, 0x48
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbx
    ret

.fail_free:
    mov  rcx, rsi
    call LocalFree
.fail_close:
    mov  rcx, r12
    call CloseHandle
.fail:
    xor  eax, eax
    add  rsp, 0x48
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
; file_write(const char* path, const void* data, u32 size) → eax = 1/0
;   rcx = path, rdx = data, r8d = size
; ============================================================
file_write:
    push rbx
    push rsi
    push rdi
    sub  rsp, 0x48

    mov  rbx, rcx                  ; path
    mov  rsi, rdx                  ; data
    mov  edi, r8d                  ; size

    mov  rcx, rbx
    mov  edx, 0x40000000           ; GENERIC_WRITE
    xor  r8d, r8d
    xor  r9d, r9d
    mov  qword [rsp+0x20], 2       ; CREATE_ALWAYS
    mov  qword [rsp+0x28], 0x80    ; FILE_ATTRIBUTE_NORMAL
    mov  qword [rsp+0x30], 0
    call CreateFileA
    cmp  rax, -1
    je   .fail
    test rax, rax
    jz   .fail
    mov  rbx, rax                  ; hFile

    mov  rcx, rbx
    mov  rdx, rsi
    mov  r8d, edi
    lea  r9,  [rsp+0x38]
    mov  qword [rsp+0x20], 0
    call WriteFile
    test eax, eax
    jz   .fail_close

    mov  rcx, rbx
    call CloseHandle

    mov  eax, 1
    add  rsp, 0x48
    pop  rdi
    pop  rsi
    pop  rbx
    ret

.fail_close:
    mov  rcx, rbx
    call CloseHandle
.fail:
    xor  eax, eax
    add  rsp, 0x48
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
file_free:
    test rcx, rcx
    jz   .done
    jmp  LocalFree
.done:
    ret

; ============================================================
file_write_time:
    sub  rsp, 0x58
    mov  rdx, 0
    lea  r8,  [rsp+0x20]
    call GetFileAttributesExA
    test eax, eax
    jz   .fail
    mov  rax, [rsp+0x20+20]
    add  rsp, 0x58
    ret
.fail:
    xor  eax, eax
    add  rsp, 0x58
    ret

; ============================================================
file_get_exe_dir:
    push rbx
    push rsi
    sub  rsp, 0x28

    mov  rbx, rcx
    mov  esi, edx

    xor  ecx, ecx
    mov  rdx, rbx
    mov  r8d, esi
    call GetModuleFileNameA
    test eax, eax
    jz   .fail

    mov  rdx, rbx
    mov  ecx, eax
    add  rdx, rcx
.find:
    dec  rdx
    cmp  rdx, rbx
    jl   .fail
    cmp  byte [rdx], 92
    jne  .find

    mov  byte [rdx+1], 0
    mov  rax, rdx
    sub  rax, rbx
    inc  rax

    add  rsp, 0x28
    pop  rsi
    pop  rbx
    ret
.fail:
    xor  eax, eax
    add  rsp, 0x28
    pop  rsi
    pop  rbx
    ret

; ============================================================
path_join_exe:
    push rbx
    push rsi
    push rdi
    sub  rsp, 0x20

    mov  rbx, rcx
    mov  rsi, rdx
    mov  edi, r8d

    mov  rcx, rsi
    mov  edx, edi
    call file_get_exe_dir
    test rax, rax
    jz   .fail

    mov  rcx, rsi
.scan:
    cmp  byte [rcx], 0
    je   .at_end
    inc  rcx
    jmp  .scan
.at_end:
    mov  rdx, rbx
.copy:
    mov  al, [rdx]
    mov  [rcx], al
    test al, al
    jz   .done
    inc  rcx
    inc  rdx
    jmp  .copy
.done:
    mov  eax, 1
    add  rsp, 0x20
    pop  rdi
    pop  rsi
    pop  rbx
    ret
.fail:
    xor  eax, eax
    add  rsp, 0x20
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
str_dup:
    push rbx
    push rsi
    push rdi
    sub  rsp, 0x20

    mov  rbx, rcx
    mov  rax, rbx
.len:
    cmp  byte [rax], 0
    je   .got_len
    inc  rax
    jmp  .len
.got_len:
    sub  rax, rbx
    mov  rdi, rax

    xor  ecx, ecx
    lea  rdx, [rdi+1]
    call LocalAlloc
    test rax, rax
    jz   .fail
    mov  rsi, rax

    mov  rdi, rsi
    mov  rdx, rbx
.copy:
    mov  al, [rdx]
    mov  [rdi], al
    test al, al
    jz   .copied
    inc  rdx
    inc  rdi
    jmp  .copy
.copied:
    mov  rax, rsi
    add  rsp, 0x20
    pop  rdi
    pop  rsi
    pop  rbx
    ret
.fail:
    xor  eax, eax
    add  rsp, 0x20
    pop  rdi
    pop  rsi
    pop  rbx
    ret

; ============================================================
str_free:
    jmp  file_free
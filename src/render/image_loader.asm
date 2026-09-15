; ============================================================
; src/render/image_loader.asm
; Image loading via GDI+ flat API
; Output: 32-bit BGRA pixel buffer, ready for glTexImage2D
; ============================================================
BITS 64
default rel

extern GdiplusStartup
extern GdiplusShutdown
extern GdipCreateBitmapFromFile
extern GdipGetImageWidth
extern GdipGetImageHeight
extern GdipBitmapLockBits
extern GdipBitmapUnlockBits
extern GdipDisposeImage
extern MultiByteToWideChar
extern LocalAlloc
extern LocalFree

section .data
align 8
gdiplus_startup_input:
    dd 1                          ; GdiplusVersion = 1
    dd 0                          ; padding
    dq 0                          ; DebugEventCallback
    dd 0                          ; SuppressBackgroundThread
    dd 0                          ; SuppressExternalCodecs

section .bss
align 8
gdiplus_token: resq 1

section .text
global image_init
global image_shutdown
global image_load

; ============================================================
image_init:
    sub  rsp, 0x28
    lea  rcx, [gdiplus_token]
    lea  rdx, [gdiplus_startup_input]
    xor  r8d, r8d
    call GdiplusStartup
    test eax, eax
    jnz  .fail
    mov  eax, 1
    add  rsp, 0x28
    ret
.fail:
    xor  eax, eax
    add  rsp, 0x28
    ret

; ============================================================
image_shutdown:
    sub  rsp, 0x28
    mov  rcx, [gdiplus_token]
    test rcx, rcx
    jz   .done
    call GdiplusShutdown
    mov  qword [gdiplus_token], 0
.done:
    add  rsp, 0x28
    ret

; ============================================================
; image_load(const char* path, u32* out_w, u32* out_h)
;   rcx = ANSI path, rdx = out_w, r8 = out_h
; Returns: rax = BGRA8 pixel buffer (LocalAlloc) or 0
;
; Requires image_init() to have been called once at startup.
; ============================================================
image_load:
    push rbx
    push rbp
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 0x328                ; ← fixed: was 0x330, now 16-aligned

    ; ---- frame layout (offset from rsp) ----
    ; +0x20..0x2F : shadow / stack args
    ; +0x50..0x257: wide path (260 WCHARs = 520 bytes)
    ; +0x260..0x27F: BitmapData (32 bytes)
    ; +0x280      : width   (u32)
    ; +0x284      : height  (u32)
    ; +0x288..0x297: GpRect (x,y,w,h — 16 bytes)
    ; +0x298      : bitmap ptr (GpBitmap*)
    ; +0x2A0      : pixel buffer ptr
    ; +0x2A8      : stride (u32)
    ; +0x2AC      : bytes_per_row (u32)
    ; +0x2B0..    : spare

    mov  r12, rcx                  ; path
    mov  r13, rdx                  ; out_w
    mov  r14, r8                   ; out_h

    mov  qword [rsp+0x298], 0
    mov  qword [rsp+0x2A0], 0

    ; ---- 1. MultiByteToWideChar ----
    xor  ecx, ecx
    xor  edx, edx
    mov  r8,  r12
    mov  r9d, -1
    lea  rax, [rsp+0x50]
    mov  [rsp+0x20], rax
    mov  qword [rsp+0x28], 260
    call MultiByteToWideChar
    test eax, eax
    jz   .fail

    ; ---- 2. GdipCreateBitmapFromFile(wide, &bitmap) ----
    lea  rcx, [rsp+0x50]
    lea  rdx, [rsp+0x298]
    call GdipCreateBitmapFromFile
    test eax, eax
    jnz  .fail

    ; ---- 3. GdipGetImageWidth(bitmap, &width) ----
    mov  rcx, [rsp+0x298]
    lea  rdx, [rsp+0x280]
    call GdipGetImageWidth
    test eax, eax
    jnz  .dispose

    ; ---- 4. GdipGetImageHeight(bitmap, &height) ----
    mov  rcx, [rsp+0x298]
    lea  rdx, [rsp+0x284]
    call GdipGetImageHeight
    test eax, eax
    jnz  .dispose

    ; ---- 5. rect = {0, 0, width, height} ----
    mov  dword [rsp+0x288], 0
    mov  dword [rsp+0x28C], 0
    mov  eax, [rsp+0x280]
    mov  [rsp+0x290], eax
    mov  eax, [rsp+0x284]
    mov  [rsp+0x294], eax

    ; ---- 6. GdipBitmapLockBits ----
    ;      rcx=bitmap, rdx=&rect, r8d=flags, r9d=format,
    ;      [rsp+0x20] = &BitmapData
    mov  rcx, [rsp+0x298]
    lea  rdx, [rsp+0x288]
    mov  r8d, 1                    ; ImageLockModeRead
    mov  r9d, 0x0026200A           ; PixelFormat32bppARGB
    lea  rax, [rsp+0x260]
    mov  [rsp+0x20], rax
    call GdipBitmapLockBits
    test eax, eax
    jnz  .dispose

    ; ---- 7. allocate pixel buffer ----
    mov  eax, [rsp+0x280]
    imul eax, [rsp+0x284]
    shl  eax, 2
    xor  ecx, ecx                  ; LMEM_FIXED
    mov  edx, eax
    call LocalAlloc
    test rax, rax
    jz   .unlock
    mov  r15, rax
    mov  [rsp+0x2A0], rax

    ; ---- 8. copy rows (handle stride vs. width*4) ----
    mov  rsi, [rsp+0x260+16]       ; scan0
    mov  eax, [rsp+0x260+8]        ; stride
    mov  [rsp+0x2A8], eax
    mov  eax, [rsp+0x280]          ; width
    shl  eax, 2
    mov  [rsp+0x2AC], eax

    mov  rdi, r15
    mov  r10d, [rsp+0x284]         ; remaining rows

.copy_row:
    test r10d, r10d
    jz   .copy_done

    mov  ecx, [rsp+0x2AC]
    rep movsb

    ; advance src by (stride - bytes_per_row)
    movsxd rax, dword [rsp+0x2A8]
    movsxd rdx, dword [rsp+0x2AC]
    sub  rax, rdx
    add  rsi, rax

    dec  r10d
    jmp  .copy_row

.copy_done:
    ; ---- 9. unlock ----
    mov  rcx, [rsp+0x298]
    lea  rdx, [rsp+0x260]
    call GdipBitmapUnlockBits

    ; ---- 10. dispose ----
    mov  rcx, [rsp+0x298]
    call GdipDisposeImage

    ; ---- 11. outputs ----
    mov  eax, [rsp+0x280]
    mov  [r13], eax
    mov  eax, [rsp+0x284]
    mov  [r14], eax

    mov  rax, r15
    jmp  .done

.unlock:
    mov  rcx, [rsp+0x298]
    lea  rdx, [rsp+0x260]
    call GdipBitmapUnlockBits

.dispose:
    mov  rcx, [rsp+0x298]
    test rcx, rcx
    jz   .fail
    call GdipDisposeImage

.fail:
    xor  eax, eax

.done:
    add  rsp, 0x328
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rdi
    pop  rsi
    pop  rbp
    pop  rbx
    ret

BITS 64
default rel

%define WIDTH 640
%define HEIGHT 480
%define WIN_STYLE 0x00CF0000
%define CW_USEDEFAULT 0x80000000
%define CS_HREDRAW 0x0002
%define CS_VREDRAW 0x0001
%define CS_OWNDC 0x0020
%define SW_SHOW 5
%define PM_REMOVE 1
%define WM_DESTROY 0x0002
%define WM_KEYDOWN 0x0100
%define VK_ESCAPE 0x1B
%define VK_W 0x57
%define VK_S 0x53
%define VK_A 0x41
%define VK_D 0x44
%define VK_Q 0x51
%define VK_E 0x45
%define VK_1 0x31
%define VK_2 0x32
%define WM_QUIT 0x0012
%define SRCCOPY 0x00CC0020
%define BLACKNESS 0x00000042

extern GetModuleHandleA
extern RegisterClassExA
extern AdjustWindowRect
extern CreateWindowExA
extern ShowWindow
extern UpdateWindow
extern PeekMessageA
extern TranslateMessage
extern DispatchMessageA
extern DefWindowProcA
extern PostQuitMessage
extern DestroyWindow
extern CreateCompatibleDC
extern CreateCompatibleBitmap
extern SelectObject
extern DeleteObject
extern CreateSolidBrush
extern Polygon
extern PatBlt
extern BitBlt
extern GetDC
extern ReleaseDC

section .data
align 16
className db "CubeClass",0
windowTitle db "3D Cube - WASD+QE, 1/2 mesh",0

align 16
vertices_l1:
    dq -1.0, -1.0, -1.0
    dq  1.0, -1.0, -1.0
    dq  1.0,  1.0, -1.0
    dq -1.0,  1.0, -1.0
    dq -1.0, -1.0,  1.0
    dq  1.0, -1.0,  1.0
    dq  1.0,  1.0,  1.0
    dq -1.0,  1.0,  1.0

faceIndices_l1:
    dd 0,1,2, 0,2,3
    dd 5,4,7, 5,7,6
    dd 4,0,3, 4,3,7
    dd 1,5,6, 1,6,2
    dd 3,2,6, 3,6,7
    dd 4,5,1, 4,1,0

baseColors_l1:
    dd 0x000000FF, 0x000000FF
    dd 0x0000FF00, 0x0000FF00
    dd 0x00FF0000, 0x00FF0000
    dd 0x0000FFFF, 0x0000FFFF
    dd 0x00FF00FF, 0x00FF00FF
    dd 0x00FFFF00, 0x00FFFF00

vertices_l2:
    dq -1.0, -1.0, -1.0
    dq  1.0, -1.0, -1.0
    dq  1.0,  1.0, -1.0
    dq -1.0,  1.0, -1.0
    dq -1.0, -1.0,  1.0
    dq  1.0, -1.0,  1.0
    dq  1.0,  1.0,  1.0
    dq -1.0,  1.0,  1.0
    dq  0.0,  0.0, -1.0
    dq  0.0,  0.0,  1.0
    dq -1.0,  0.0,  0.0
    dq  1.0,  0.0,  0.0
    dq  0.0, -1.0,  0.0
    dq  0.0,  1.0,  0.0

faceIndices_l2:
    dd 8,1,0,  8,2,1,  8,3,2,  8,0,3
    dd 9,4,5,  9,5,6,  9,6,7,  9,7,4
    dd 10,3,0,  10,7,3,  10,4,7,  10,0,4
    dd 11,1,2,  11,2,6,  11,6,5,  11,5,1
    dd 12,1,0,  12,5,1,  12,4,5,  12,0,4
    dd 13,3,2,  13,2,6,  13,6,7,  13,7,3

baseColors_l2:
    dd 0x000000FF, 0x000000FF, 0x000000FF, 0x000000FF
    dd 0x0000FF00, 0x0000FF00, 0x0000FF00, 0x0000FF00
    dd 0x00FF0000, 0x00FF0000, 0x00FF0000, 0x00FF0000
    dd 0x0000FFFF, 0x0000FFFF, 0x0000FFFF, 0x0000FFFF
    dd 0x00FF00FF, 0x00FF00FF, 0x00FF00FF, 0x00FF00FF
    dd 0x00FFFF00, 0x00FFFF00, 0x00FFFF00, 0x00FFFF00

align 16
lightDir:
    dq 0.408248290463863, -0.408248290463863, 0.816496580927726
ambient dq 0.25
diffuse dq 0.75
one dq 1.0
minus_one dq -1.0
focal dq 300.0
dist dq 5.0
centerX dq 320.0
centerY dq 240.0
deltaY dq 0.004
deltaX dq 0.003
scale255 dq 255.0

camDist dq 8.0
camYaw dq 0.0
camPitch dq 0.0
camX dq 0.0
camY dq 0.0
camZ dq 0.0
camSpeed dq 0.1
rotSpeed dq 0.02

section .bss
align 16
hInstance resq 1
hwnd resq 1
memDC resq 1
hBitmap resq 1
oldBitmap resq 1

wcex resb 80
rect resb 16
msg resb 48

angleX resq 1
angleY resq 1
sinX resq 1
cosX resq 1
sinY resq 1
cosY resq 1
sinCamYaw resq 1
cosCamYaw resq 1
sinCamPitch resq 1
cosCamPitch resq 1

meshLevel resd 1
numVerts resd 1
numFaces resd 1
verticesPtr resq 1
faceIndicesPtr resq 1
baseColorsPtr resq 1

rotVerts resq 42
viewVerts resq 42
screenX resd 14
screenY resd 14
depthVerts resq 14

MAX_TRIANGLES equ 128
TRI_ENTRY_SIZE equ 40
sortedTris resb MAX_TRIANGLES * TRI_ENTRY_SIZE
numTris resd 1

triPoints resb 24
tempI0 resd 1
tempI1 resd 1
tempI2 resd 1
brushH resq 1
oldBrushH resq 1

section .text
global WinMain

WinMain:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    sub rsp, 0x40

    xor ecx, ecx
    call GetModuleHandleA
    mov [hInstance], rax

    mov dword [wcex+0], 80
    mov dword [wcex+4], CS_HREDRAW | CS_VREDRAW | CS_OWNDC
    lea rax, [WndProc]
    mov [wcex+8], rax
    mov dword [wcex+16], 0
    mov dword [wcex+20], 0
    mov rax, [hInstance]
    mov [wcex+24], rax
    xor rax, rax
    mov [wcex+32], rax
    mov [wcex+40], rax
    mov [wcex+48], rax
    mov [wcex+56], rax
    lea rax, [className]
    mov [wcex+64], rax
    mov qword [wcex+72], 0

    lea rcx, [wcex]
    call RegisterClassExA
    test rax, rax
    jz .exit

    mov dword [rect+0], 0
    mov dword [rect+4], 0
    mov dword [rect+8], WIDTH
    mov dword [rect+12], HEIGHT
    lea rcx, [rect]
    mov rdx, WIN_STYLE
    xor r8d, r8d
    call AdjustWindowRect

    mov eax, dword [rect+8]
    sub eax, dword [rect+0]
    mov ebx, eax
    mov eax, dword [rect+12]
    sub eax, dword [rect+4]
    mov esi, eax

    sub rsp, 0x60
    xor ecx, ecx
    lea rdx, [className]
    lea r8, [windowTitle]
    mov r9d, WIN_STYLE
    mov r10d, CW_USEDEFAULT
    mov [rsp+32], r10
    mov [rsp+40], r10
    movsxd r10, ebx
    mov [rsp+48], r10
    movsxd r10, esi
    mov [rsp+56], r10
    mov qword [rsp+64], 0
    mov qword [rsp+72], 0
    mov rax, [hInstance]
    mov [rsp+80], rax
    mov qword [rsp+88], 0
    call CreateWindowExA
    add rsp, 0x60
    test rax, rax
    jz .exit
    mov [hwnd], rax

    mov rcx, rax
    mov edx, SW_SHOW
    call ShowWindow
    mov rcx, [hwnd]
    call UpdateWindow

    call init_backbuffer
    test eax, eax
    jz .exit

    mov dword [meshLevel], 2
    call set_mesh_level

.loop:
    sub rsp, 0x30
    lea rcx, [msg]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    mov dword [rsp+32], PM_REMOVE
    call PeekMessageA
    add rsp, 0x30
    test eax, eax
    jz .render

    cmp dword [msg+8], WM_QUIT
    je .exit
    lea rcx, [msg]
    call TranslateMessage
    lea rcx, [msg]
    call DispatchMessageA
    jmp .loop

.render:
    call render_frame
    jmp .loop

.exit:
    mov rcx, [memDC]
    mov rdx, [oldBitmap]
    call SelectObject
    mov rcx, [hBitmap]
    call DeleteObject
    mov rcx, [memDC]
    call DeleteObject

    add rsp, 0x40
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    xor eax, eax
    ret

WndProc:
    sub rsp, 0x28
    cmp edx, WM_DESTROY
    je .destroy
    cmp edx, WM_KEYDOWN
    je .keydown
    add rsp, 0x28
    jmp DefWindowProcA
.destroy:
    xor ecx, ecx
    call PostQuitMessage
    add rsp, 0x28
    xor eax, eax
    ret
.keydown:
    cmp r8d, VK_ESCAPE
    je .esc
    cmp r8d, VK_W
    je .key_w
    cmp r8d, VK_S
    je .key_s
    cmp r8d, VK_A
    je .key_a
    cmp r8d, VK_D
    je .key_d
    cmp r8d, VK_Q
    je .key_q
    cmp r8d, VK_E
    je .key_e
    cmp r8d, VK_1
    je .key_1
    cmp r8d, VK_2
    je .key_2
    jmp .def

.esc:
    call DestroyWindow
    add rsp, 0x28
    xor eax, eax
    ret

.key_w:
    movsd xmm0, [camDist]
    subsd xmm0, [camSpeed]
    movsd [camDist], xmm0
    jmp .key_done
.key_s:
    movsd xmm0, [camDist]
    addsd xmm0, [camSpeed]
    movsd [camDist], xmm0
    jmp .key_done
.key_a:
    movsd xmm0, [camYaw]
    subsd xmm0, [rotSpeed]
    movsd [camYaw], xmm0
    jmp .key_done
.key_d:
    movsd xmm0, [camYaw]
    addsd xmm0, [rotSpeed]
    movsd [camYaw], xmm0
    jmp .key_done
.key_q:
    movsd xmm0, [camPitch]
    subsd xmm0, [rotSpeed]
    movsd [camPitch], xmm0
    jmp .key_done
.key_e:
    movsd xmm0, [camPitch]
    addsd xmm0, [rotSpeed]
    movsd [camPitch], xmm0
    jmp .key_done
.key_1:
    mov dword [meshLevel], 1
    call set_mesh_level
    jmp .key_done
.key_2:
    mov dword [meshLevel], 2
    call set_mesh_level
.key_done:
    add rsp, 0x28
    xor eax, eax
    ret
.def:
    add rsp, 0x28
    jmp DefWindowProcA

set_mesh_level:
    push rbx
    sub rsp, 0x20
    mov eax, [meshLevel]
    cmp eax, 1
    je .level1
    lea rax, [vertices_l2]
    mov [verticesPtr], rax
    lea rax, [faceIndices_l2]
    mov [faceIndicesPtr], rax
    lea rax, [baseColors_l2]
    mov [baseColorsPtr], rax
    mov dword [numVerts], 14
    mov dword [numFaces], 24
    jmp .done
.level1:
    lea rax, [vertices_l1]
    mov [verticesPtr], rax
    lea rax, [faceIndices_l1]
    mov [faceIndicesPtr], rax
    lea rax, [baseColors_l1]
    mov [baseColorsPtr], rax
    mov dword [numVerts], 8
    mov dword [numFaces], 12
.done:
    add rsp, 0x20
    pop rbx
    ret

init_backbuffer:
    push rbx
    sub rsp, 0x20
    xor ecx, ecx
    call CreateCompatibleDC
    test rax, rax
    jz .fail_no_dc
    mov [memDC], rax

    mov rcx, [hwnd]
    call GetDC
    mov rbx, rax
    test rax, rax
    jz .fail_no_dc

    mov rcx, rbx
    mov edx, WIDTH
    mov r8d, HEIGHT
    call CreateCompatibleBitmap
    mov [hBitmap], rax
    test rax, rax
    jz .fail_release_dc

    mov rcx, [memDC]
    mov rdx, rax
    call SelectObject
    mov [oldBitmap], rax

    mov rcx, [hwnd]
    mov rdx, rbx
    call ReleaseDC

    mov eax, 1
    add rsp, 0x20
    pop rbx
    ret

.fail_release_dc:
    mov rcx, [hwnd]
    mov rdx, rbx
    call ReleaseDC
.fail_no_dc:
    xor eax, eax
    add rsp, 0x20
    pop rbx
    ret

compute_intensity:
    movsd xmm0, [rdx]
    subsd xmm0, [rcx]
    movsd xmm1, [rdx+8]
    subsd xmm1, [rcx+8]
    movsd xmm2, [rdx+16]
    subsd xmm2, [rcx+16]

    movsd xmm3, [r8]
    subsd xmm3, [rcx]
    movsd xmm4, [r8+8]
    subsd xmm4, [rcx+8]
    movsd xmm5, [r8+16]
    subsd xmm5, [rcx+16]

    movsd xmm6, xmm1
    mulsd xmm6, xmm5
    movsd xmm7, xmm2
    mulsd xmm7, xmm4
    subsd xmm6, xmm7

    movsd xmm7, xmm2
    mulsd xmm7, xmm3
    movsd xmm8, xmm0
    mulsd xmm8, xmm5
    subsd xmm7, xmm8

    movsd xmm8, xmm0
    mulsd xmm8, xmm4
    movsd xmm9, xmm1
    mulsd xmm9, xmm3
    subsd xmm8, xmm9

    movsd xmm9, xmm6
    mulsd xmm9, xmm6
    movsd xmm10, xmm7
    mulsd xmm10, xmm7
    addsd xmm9, xmm10
    movsd xmm10, xmm8
    mulsd xmm10, xmm8
    addsd xmm9, xmm10

    pxor xmm10, xmm10
    comisd xmm9, xmm10
    jbe .backface

    sqrtsd xmm9, xmm9
    divsd xmm6, xmm9
    divsd xmm7, xmm9
    divsd xmm8, xmm9

    movsd xmm0, xmm6
    mulsd xmm0, [lightDir]
    movsd xmm1, xmm7
    mulsd xmm1, [lightDir+8]
    addsd xmm0, xmm1
    movsd xmm1, xmm8
    mulsd xmm1, [lightDir+16]
    addsd xmm0, xmm1

    pxor xmm11, xmm11
    comisd xmm0, xmm11
    jbe .backface

    mulsd xmm0, [diffuse]
    addsd xmm0, [ambient]
    movsd xmm1, [one]
    comisd xmm0, xmm1
    jbe .done
    movsd xmm0, xmm1
.done:
    ret
.backface:
    movsd xmm0, [minus_one]
    ret

shade_color:
    mulsd xmm0, [scale255]
    cvttsd2si eax, xmm0
    test eax, eax
    jns .positive
    xor eax, eax
.positive:
    cmp eax, 255
    jle .ok
    mov eax, 255
.ok:
    mov ecx, edi
    and ecx, 0xFF
    imul ecx, eax
    shr ecx, 8

    mov edx, edi
    shr edx, 8
    and edx, 0xFF
    imul edx, eax
    shr edx, 8
    shl edx, 8
    or ecx, edx

    mov edx, edi
    shr edx, 16
    and edx, 0xFF
    imul edx, eax
    shr edx, 8
    shl edx, 16
    or ecx, edx

    mov eax, ecx
    ret

sort_triangles:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    sub rsp, 0x30

    mov r12d, [rel numTris]
    cmp r12d, 1
    jle .done

    lea r11, [rel sortedTris]   
    mov esi, 1
.loop_i:
    mov ebx, esi
    mov ecx, esi
    imul ecx, TRI_ENTRY_SIZE
    lea rdx, [r11 + rcx]          ; corrected

.loop_j:
    test ebx, ebx
    jz .next_i
    mov ecx, ebx
    imul ecx, TRI_ENTRY_SIZE
    lea r8, [r11 + rcx - TRI_ENTRY_SIZE]  ; corrected

    movsd xmm0, [r8 + 24]
    movsd xmm1, [r8 + 24 + TRI_ENTRY_SIZE]
    comisd xmm0, xmm1
    jbe .swap_done

    lea rsi, [r8]
    lea rdi, [r8 + TRI_ENTRY_SIZE]
    mov ecx, TRI_ENTRY_SIZE
    rep movsb

    dec ebx
    jmp .loop_j

.swap_done:
    dec ebx
    jmp .loop_j

.next_i:
    inc esi
    cmp esi, r12d
    jl .loop_i

.done:
    add rsp, 0x30
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

render_frame:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    sub rsp, 0x48

    movsd xmm0, [angleY]
    addsd xmm0, [deltaY]
    movsd [angleY], xmm0
    movsd xmm0, [angleX]
    addsd xmm0, [deltaX]
    movsd [angleX], xmm0

    fld qword [angleY]
    fsincos
    fstp qword [cosY]
    fstp qword [sinY]
    fld qword [angleX]
    fsincos
    fstp qword [cosX]
    fstp qword [sinX]

    fld qword [camYaw]
    fsincos
    fstp qword [cosCamYaw]
    fstp qword [sinCamYaw]
    fld qword [camPitch]
    fsincos
    fstp qword [cosCamPitch]
    fstp qword [sinCamPitch]

    ; Compute camera position
    movsd xmm0, [camDist]
    mulsd xmm0, [cosCamPitch]
    mulsd xmm0, [sinCamYaw]
    movsd [camX], xmm0

    movsd xmm0, [camDist]
    mulsd xmm0, [sinCamPitch]
    movsd [camY], xmm0

    movsd xmm0, [camDist]
    mulsd xmm0, [cosCamPitch]
    mulsd xmm0, [cosCamYaw]
    movsd [camZ], xmm0

    ; Transform vertices
    mov ecx, [rel numVerts]
    mov rsi, [rel verticesPtr]
    lea rdi, [rotVerts]
    lea rbx, [viewVerts]

.vrotate_loop:
    movsd xmm0, [rsi]
    movsd xmm1, [rsi+8]
    movsd xmm2, [rsi+16]

    movsd xmm3, xmm0
    mulsd xmm3, [cosY]
    movsd xmm4, xmm2
    mulsd xmm4, [sinY]
    addsd xmm3, xmm4

    movsd xmm5, xmm0
    mulsd xmm5, [sinY]
    movsd xmm4, xmm2
    mulsd xmm4, [cosY]
    subsd xmm4, xmm5

    movsd xmm6, xmm1
    mulsd xmm6, [cosX]
    movsd xmm7, xmm4
    mulsd xmm7, [sinX]
    subsd xmm6, xmm7

    movsd xmm7, xmm1
    mulsd xmm7, [sinX]
    movsd xmm5, xmm4
    mulsd xmm5, [cosX]
    addsd xmm5, xmm7

    movsd [rdi], xmm3
    movsd [rdi+8], xmm6
    movsd [rdi+16], xmm5

    ; view transform
    movsd xmm0, xmm3
    subsd xmm0, [camX]
    movsd xmm1, xmm6
    subsd xmm1, [camY]
    movsd xmm2, xmm5
    subsd xmm2, [camZ]

    movsd xmm3, xmm0
    mulsd xmm3, [cosCamYaw]
    movsd xmm4, xmm2
    mulsd xmm4, [sinCamYaw]
    subsd xmm3, xmm4

    movsd xmm4, xmm0
    mulsd xmm4, [sinCamYaw]
    movsd xmm5, xmm2
    mulsd xmm5, [cosCamYaw]
    addsd xmm5, xmm4

    movsd xmm6, xmm1
    mulsd xmm6, [cosCamPitch]
    movsd xmm7, xmm5
    mulsd xmm7, [sinCamPitch]
    addsd xmm6, xmm7

    movsd xmm7, xmm1
    mulsd xmm7, [sinCamPitch]
    movsd xmm8, xmm5
    mulsd xmm8, [cosCamPitch]
    subsd xmm8, xmm7

    movsd [rbx], xmm3
    movsd [rbx+8], xmm6
    movsd [rbx+16], xmm8

    add rsi, 24
    add rdi, 24
    add rbx, 24
    dec ecx
    jnz .vrotate_loop

    ; Project vertices
    mov ecx, [rel numVerts]
    lea rsi, [viewVerts]
    lea rdi, [screenX]
    lea rbx, [screenY]
    lea rdx, [depthVerts]
.vproj_loop:
    movsd xmm0, [rsi]
    movsd xmm1, [rsi+8]
    movsd xmm2, [rsi+16]

    movsd [rdx], xmm2    ; depth = view z

    movsd xmm3, xmm2
    addsd xmm3, [dist]   

    movsd xmm4, xmm0
    mulsd xmm4, [focal]
    divsd xmm4, xmm3
    addsd xmm4, [centerX]
    cvttsd2si eax, xmm4
    mov [rdi], eax

    movsd xmm4, xmm1
    mulsd xmm4, [focal]
    divsd xmm4, xmm3
    movsd xmm5, [centerY]
    subsd xmm5, xmm4
    cvttsd2si eax, xmm5
    mov [rbx], eax

    add rsi, 24
    add rdi, 4
    add rbx, 4
    add rdx, 8
    dec ecx
    jnz .vproj_loop

    ; Clear background
    mov rcx, [memDC]
    xor edx, edx
    xor r8d, r8d
    mov r9d, WIDTH
    sub rsp, 0x30
    mov dword [rsp+32], HEIGHT
    mov dword [rsp+40], BLACKNESS
    call PatBlt
    add rsp, 0x30

    ; Process triangles
    mov dword [rel numTris], 0
    mov r14d, [rel numFaces]
    mov rbx, [rel faceIndicesPtr]
    mov rsi, [rel baseColorsPtr]

.face_loop:
    mov eax, [rbx]
    mov r10d, [rbx+4]
    mov r11d, [rbx+8]
    mov [tempI0], eax
    mov [tempI1], r10d
    mov [tempI2], r11d

    imul eax, 24
    imul r10d, 24
    imul r11d, 24
    lea r9, [rotVerts]
    lea rcx, [r9 + rax]
    lea rdx, [r9 + r10]
    lea r8,  [r9 + r11]
    call compute_intensity

    pxor xmm1, xmm1
    comisd xmm0, xmm1
    jb .skip_face

    mov edi, [rsi]
    call shade_color
    mov r12d, eax

    ; average depth
    lea r8, [depthVerts]
    mov eax, [tempI0]
    movsxd r10, eax
    movsd xmm0, [r8 + r10*8]
    mov eax, [tempI1]
    movsxd r10, eax
    addsd xmm0, [r8 + r10*8]
    mov eax, [tempI2]
    movsxd r10, eax
    addsd xmm0, [r8 + r10*8]
    movsd xmm2, [one]
    addsd xmm2, [one]
    addsd xmm2, [one]  ; 3.0
    divsd xmm0, xmm2

    ; store sorted triangle
    lea rdi, [sortedTris]
    mov eax, [rel numTris]
    imul eax, TRI_ENTRY_SIZE
    add rdi, rax

    lea r8, [screenX]
    lea r9, [screenY]

    mov eax, [tempI0]
    movsxd r10, eax
    mov edx, [r8 + r10*4]
    mov [rdi], edx
    mov edx, [r9 + r10*4]
    mov [rdi+4], edx

    mov eax, [tempI1]
    movsxd r10, eax
    mov edx, [r8 + r10*4]
    mov [rdi+8], edx
    mov edx, [r9 + r10*4]
    mov [rdi+12], edx

    mov eax, [tempI2]
    movsxd r10, eax
    mov edx, [r8 + r10*4]
    mov [rdi+16], edx
    mov edx, [r9 + r10*4]
    mov [rdi+20], edx

    movsd [rdi+24], xmm0
    mov [rdi+32], r12d

    inc dword [rel numTris]

.skip_face:
    add rbx, 12
    add rsi, 4
    dec r14d
    jnz .face_loop

    call sort_triangles

    ; Draw triangles
    mov r14d, [rel numTris]
    lea rbx, [sortedTris]
.draw_loop:
    mov r12d, [rbx+32]
    mov ecx, r12d
    call CreateSolidBrush
    test rax, rax
    jz .skip_draw
    mov [brushH], rax

    mov rcx, [memDC]
    mov rdx, rax
    call SelectObject
    mov [oldBrushH], rax

    lea rdi, [triPoints]
    mov eax, [rbx]
    mov [rdi], eax
    mov eax, [rbx+4]
    mov [rdi+4], eax
    mov eax, [rbx+8]
    mov [rdi+8], eax
    mov eax, [rbx+12]
    mov [rdi+12], eax
    mov eax, [rbx+16]
    mov [rdi+16], eax
    mov eax, [rbx+20]
    mov [rdi+20], eax

    mov rcx, [memDC]
    lea rdx, [triPoints]
    mov r8d, 3
    call Polygon

    mov rcx, [memDC]
    mov rdx, [oldBrushH]
    call SelectObject

    mov rcx, [brushH]
    call DeleteObject

.skip_draw:
    add rbx, TRI_ENTRY_SIZE
    dec r14d
    jnz .draw_loop

    ; Present
    mov rcx, [hwnd]
    call GetDC
    mov rbx, rax

    mov rcx, rbx
    xor edx, edx
    xor r8d, r8d
    mov r9d, WIDTH
    sub rsp, 0x50
    mov dword [rsp+32], HEIGHT
    mov rax, [memDC]
    mov [rsp+40], rax
    mov dword [rsp+48], 0
    mov dword [rsp+56], 0
    mov dword [rsp+64], SRCCOPY
    call BitBlt
    add rsp, 0x50

    mov rcx, [hwnd]
    mov rdx, rbx
    call ReleaseDC

    add rsp, 0x48
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret
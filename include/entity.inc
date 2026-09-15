%ifndef ENTITY_INC
%define ENTITY_INC

; ============================================================
; Entity — a "game object" slot
; ============================================================
%define ENTITY_SIZE         80        ; was 64
%define MAX_ENTITIES        64

; ---- Layout (80 bytes) ----
;   +0   u32  type
;   +4   u32  flags
;   +8   f32  pos_x
;   +12  f32  pos_y
;   +16  f32  pos_z
;   +20  f32  rot_y
;   +24  f32  rot_speed
;   +28  f32  scale
;   +32  f32  color_r
;   +36  f32  color_g
;   +40  f32  color_b
;   +44  u32  texture
;   +48  f32  vel_x
;   +52  f32  vel_y
;   +56  f32  vel_z
;   +60  f32  half_h
;   +64  f32  rot_x          ← NEW
;   +68  f32  rot_z          ← NEW
;   +72  u32  pad2
;   +76  u32  pad3

%define E_TYPE              0
%define E_FLAGS             4
%define E_POS               8
%define E_ROT_Y             20
%define E_ROT_SPEED         24
%define E_SCALE             28
%define E_COLOR             32
%define E_TEXTURE           44
%define E_VEL               48
%define E_HALF_H            60
%define E_ROT_X             64
%define E_ROT_Z             68
%define E_PAD2              72
%define E_PAD3              76

%define E_TYPE_EMPTY        0xFFFFFFFF
%define E_TYPE_CUBE         0
%define E_TYPE_SPHERE       1
%define E_TYPE_PYRAMID      2

%endif
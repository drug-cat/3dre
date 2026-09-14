%ifndef MESH_INC
%define MESH_INC

; ============================================================
; Mesh — GPU-resident vertex + index buffers
; ============================================================
%define MESH_SIZE           32

%define MESH_VAO            0       ; u32
%define MESH_VBO            4       ; u32
%define MESH_EBO            8       ; u32
%define MESH_INDEX_COUNT    12      ; u32  — number of indices (for glDrawElements)
%define MESH_VERT_COUNT     16      ; u32
%define MESH_STRIDE         20      ; u32  — bytes per vertex
%define MESH_FLAGS          24      ; u32  — reserved for future
%define MESH_PAD            28      ; u32

; ---- Vertex layout convention ----
;   offset 0  : position.xyz  (3 × f32)
;   offset 12 : color.rgb     (3 × f32)
;   stride    : 24 bytes
%define MESH_VERTEX_SIZE    24
%define MESH_ATTR_POS       0
%define MESH_ATTR_COLOR     1
%define MESH_ATTR_POS_OFF   0
%define MESH_ATTR_COLOR_OFF 12

%endif
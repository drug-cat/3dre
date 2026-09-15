%ifndef MESH_INC
%define MESH_INC

%define MESH_SIZE           32

%define MESH_VAO            0
%define MESH_VBO            4
%define MESH_EBO            8
%define MESH_INDEX_COUNT    12
%define MESH_VERT_COUNT     16
%define MESH_STRIDE         20
%define MESH_FLAGS          24
%define MESH_PAD            28

; ---- Vertex layout (44 bytes) ----
;   0  : position.xyz   (3 × f32)
;   12 : color.rgb      (3 × f32)
;   24 : normal.xyz     (3 × f32)
;   36 : uv.xy          (2 × f32)
%define MESH_VERTEX_SIZE    44
%define MESH_ATTR_POS       0
%define MESH_ATTR_COLOR     1
%define MESH_ATTR_NORMAL    2
%define MESH_ATTR_UV        3
%define MESH_ATTR_POS_OFF    0
%define MESH_ATTR_COLOR_OFF  12
%define MESH_ATTR_NORMAL_OFF 24
%define MESH_ATTR_UV_OFF     36

%endif
%ifndef GL_INC
%define GL_INC

; ---- Types ----
%define GL_FLOAT                 0x1406
%define GL_UNSIGNED_INT          0x1405
%define GL_UNSIGNED_BYTE         0x1401
%define GL_FALSE                 0
%define GL_TRUE                  1

; ---- Primitives ----
%define GL_POINTS                0x0000
%define GL_LINES                 0x0001
%define GL_TRIANGLES             0x0004
%define GL_TRIANGLE_STRIP        0x0005
%define GL_TRIANGLE_FAN          0x0006

; ---- Buffers ----
%define GL_ARRAY_BUFFER          0x8892
%define GL_ELEMENT_ARRAY_BUFFER  0x8893
%define GL_STATIC_DRAW           0x88E4
%define GL_DYNAMIC_DRAW          0x88E8
%define GL_STREAM_DRAW           0x88E0

; ---- Shaders ----
%define GL_VERTEX_SHADER         0x8B31
%define GL_FRAGMENT_SHADER       0x8B30
%define GL_COMPILE_STATUS        0x8B81
%define GL_LINK_STATUS           0x8B82
%define GL_INFO_LOG_LENGTH       0x8B84

; ---- State ----
%define GL_DEPTH_TEST            0x0B71
%define GL_CULL_FACE             0x0B44
%define GL_BACK                  0x0405
%define GL_FRONT                 0x0404
%define GL_CCW                   0x0901
%define GL_CW                    0x0900
%define GL_BLEND                 0x0BE2
%define GL_SRC_ALPHA             0x0302
%define GL_ONE_MINUS_SRC_ALPHA   0x0303
%define GL_COLOR_BUFFER_BIT      0x00004000
%define GL_DEPTH_BUFFER_BIT      0x00000100
%define GL_STENCIL_BUFFER_BIT    0x00000400

; ---- Strings ----
%define GL_VENDOR                0x1F00
%define GL_RENDERER              0x1F01
%define GL_VERSION               0x1F02
%define GL_SHADING_LANGUAGE_VERSION 0x8B8C

; ---- WGL ARB ----
%define WGL_CONTEXT_MAJOR_VERSION_ARB     0x2091
%define WGL_CONTEXT_MINOR_VERSION_ARB     0x2092
%define WGL_CONTEXT_PROFILE_MASK_ARB      0x9126
%define WGL_CONTEXT_CORE_PROFILE_BIT_ARB  0x00000001
%define WGL_CONTEXT_FLAGS_ARB             0x2094
; ---- Textures ----
%define GL_TEXTURE_2D            0x0DE1
%define GL_TEXTURE0              0x84C0
%define GL_TEXTURE1              0x84C1
%define GL_RGB                   0x1907
%define GL_RGBA                  0x1908
%define GL_RED                   0x1903
%define GL_NEAREST               0x2600
%define GL_LINEAR                0x2601
%define GL_NEAREST_MIPMAP_NEAREST 0x2700
%define GL_LINEAR_MIPMAP_LINEAR  0x2703
%define GL_REPEAT                0x2901
%define GL_CLAMP_TO_EDGE         0x812F
%define GL_TEXTURE_WRAP_S        0x2802
%define GL_TEXTURE_WRAP_T        0x2803
%define GL_TEXTURE_MIN_FILTER    0x2801
%define GL_TEXTURE_MAG_FILTER    0x2800
%define GL_UNPACK_ALIGNMENT      0x0CF5
%define GL_PIXEL_UNPACK_BUFFER   0x88EC
%define GL_BGRA   0x80E1

; ---- GL 1.1 texture functions (direct from opengl32.dll) ----
extern glGenTextures
extern glDeleteTextures
extern glBindTexture
extern glTexImage2D
extern glTexParameteri
; ---- GL 1.1 exports from opengl32.dll ----
extern glClear
extern glClearColor
extern glViewport
extern glGetString
extern glGetError
extern glEnable
extern glDisable

%endif
%ifndef SHADER_INC
%define SHADER_INC

; ShaderProgram struct — 64 bytes
%define SP_SIZE         64

%define SP_ID           0       ; u32  gl program id
%define SP_FLAGS        4       ; u32
%define SP_VS_PATH      8       ; qword  heap-allocated absolute path
%define SP_FS_PATH      16      ; qword
%define SP_VS_WTIME     24      ; qword  FILETIME packed
%define SP_FS_WTIME     32      ; qword
%define SP_VS_BUF       40      ; qword  last source (for diagnostics)
%define SP_FS_BUF       48      ; qword
%define SP_VS_SIZE      56      ; u32
%define SP_FS_SIZE      60      ; u32

%endif
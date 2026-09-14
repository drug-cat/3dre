%ifndef WIN32_INC
%define WIN32_INC

%define WS_OVERLAPPEDWINDOW  0x00CF0000
%define CW_USEDEFAULT        0x80000000
%define SW_SHOW              5

%define CS_HREDRAW           0x0002
%define CS_VREDRAW           0x0001
%define CS_OWNDC             0x0020

%define WM_DESTROY           0x0002
%define WM_CLOSE             0x0010
%define WM_KEYDOWN           0x0100
%define WM_KEYUP             0x0101
%define WM_SIZE              0x0005
%define WM_QUIT              0x0012

%define PM_REMOVE            1

%define VK_ESCAPE            0x1B
%define VK_W                 0x57
%define VK_A                 0x41
%define VK_S                 0x53
%define VK_D                 0x44
%define VK_Q                 0x51
%define VK_E                 0x45

%define WM_ACTIVATE     0x0006
%define WM_SETCURSOR    0x0020
%define WA_INACTIVE     0
%define WA_ACTIVE       1
%define WA_CLICKACTIVE  2

; ---- Win32 API ----
extern GetModuleHandleA
extern RegisterClassExA
extern CreateWindowExA
extern DefWindowProcA
extern ShowWindow
extern UpdateWindow
extern PeekMessageA
extern TranslateMessage
extern DispatchMessageA
extern PostQuitMessage
extern DestroyWindow
extern GetDC
extern ReleaseDC
extern ChoosePixelFormat
extern SetPixelFormat

%endif
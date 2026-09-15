#version 330 core

layout(location = 0) in vec3 aPos;

uniform mat4 uViewProj;      // view-projection بدون translation دوربین
uniform vec3 uCameraPos;     // موقعیت دوربین توی دنیا

out vec3 vWorldDir;

void main()
{
    // مکعب حول دوربین: موقعیت vertex رو از مرکز دوربین حساب میکنیم
    vec4 worldPos = vec4(aPos * 100.0 + uCameraPos, 1.0);
    vWorldDir = aPos;   // جهت از مرکز مکعب (برای رنگ آسمان)

    // depth trick: z = w ⇒ depth = 1.0 (پشت همهچیز)
    vec4 clip = uViewProj * worldPos;
    gl_Position = clip.xyww;
}
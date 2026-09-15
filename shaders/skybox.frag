#version 330 core

in vec3 vWorldDir;
out vec4 FragColor;

void main()
{
    vec3 d = normalize(vWorldDir);

    // گرادیان ساده بر اساس ارتفاع
    // up (d.y = 1)   → آبی
    // horizon (0)    → نارنجی گرم
    // down (d.y = -1) → خاکی تیره
    vec3 sky_top     = vec3(0.20, 0.40, 0.85);
    vec3 sky_horizon = vec3(0.95, 0.65, 0.35);
    vec3 ground      = vec3(0.15, 0.13, 0.10);

    float t = d.y;                        // -1 .. 1
    vec3 col;

    if (t >= 0.0) {
        // sky → horizon
        col = mix(sky_horizon, sky_top, pow(t, 0.5));
    } else {
        // horizon → ground
        col = mix(sky_horizon, ground, pow(-t, 0.7));
    }

    FragColor = vec4(col, 1.0);
}
#version 330 core

in vec3 vColor;
in vec3 vNormal;
in vec3 vWorldPos;
in vec2 vUV;

uniform sampler2D uAlbedo;
uniform vec3  uColor;
uniform vec3  uSunDir;
uniform vec3  uSunColor;
uniform float uAmbient;
uniform vec3  uCameraPos;
uniform vec3  lightA_pos;
uniform vec3  lightA_color;
uniform vec3  lightB_pos;
uniform vec3  lightB_color;
uniform float uPointIntensity;
uniform float uUnlit;

out vec4 FragColor;

void main()
{
    if (uUnlit > 0.5) {
        FragColor = vec4(vColor * uColor, 1.0);
        return;
    }

    vec3 tex  = texture(uAlbedo, vUV).rgb;
    vec3 base = vColor * uColor * tex;

    vec3 N = normalize(vNormal);

    // ---- Sun ----
    vec3  L   = normalize(uSunDir);
    float ndl = max(dot(N, L), 0.0);
    vec3 lit = base * (uAmbient + ndl * uSunColor);

    // ---- Point light A ----
    {
        vec3  dA  = lightA_pos - vWorldPos;
        float lA  = max(dot(N, normalize(dA)), 0.0);
        lit += base * lA * lightA_color * (uPointIntensity / (1.0 + dot(dA, dA)));
    }

    // ---- Point light B ----
    {
        vec3  dB  = lightB_pos - vWorldPos;
        float lB  = max(dot(N, normalize(dB)), 0.0);
        lit += base * lB * lightB_color * (uPointIntensity / (1.0 + dot(dB, dB)));
    }

    FragColor = vec4(lit, 1.0);
}
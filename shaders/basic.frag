#version 330 core

in vec3 vColor;
in vec3 vNormal;
in vec3 vWorldPos;
in vec2 vUV;

uniform sampler2D uAlbedo;

uniform vec3  uColor;
uniform vec3  uLightDir;
uniform vec3  uLightColor;
uniform float uAmbient;

uniform vec3  uCameraPos;
uniform vec3  uSpecularColor;
uniform float uShininess;

out vec4 FragColor;

void main()
{
    vec3 tex   = texture(uAlbedo, vUV).rgb;
    vec3 base  = vColor * uColor * tex;

    vec3 N = normalize(vNormal);
    vec3 L = normalize(uLightDir);
    vec3 V = normalize(uCameraPos - vWorldPos);

    float ndl = max(dot(N, L), 0.0);

    vec3  H    = normalize(L + V);
    float ndh  = max(dot(N, H), 0.0);
    float spec = pow(ndh, uShininess);
    spec *= step(0.0001, ndl);

    vec3 lit = base * (uAmbient + ndl * uLightColor) + uSpecularColor * spec;
    FragColor = vec4(lit, 1.0);
}
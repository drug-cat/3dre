#version 330 core

in vec3 vColor;
in vec3 vNormal;
in vec3 vWorldPos;

uniform vec3  uLightDir;         // direction FROM surface TOWARD light
uniform vec3  uLightColor;
uniform float uAmbient;

uniform vec3  uCameraPos;        // world-space eye position
uniform vec3  uSpecularColor;    // tint of the highlight
uniform float uShininess;        // higher = tighter highlight

out vec4 FragColor;

void main()
{
    vec3 N = normalize(vNormal);
    vec3 L = normalize(uLightDir);
    vec3 V = normalize(uCameraPos - vWorldPos);

    // Diffuse (Lambert)
    float ndl = max(dot(N, L), 0.0);

    // Specular (Blinn-Phong half-vector)
    vec3  H    = normalize(L + V);
    float ndh  = max(dot(N, H), 0.0);
    float spec = pow(ndh, uShininess);

    // Only add specular where diffuse is non-zero (avoids weird highlights on dark backsides)
    spec *= step(0.0001, ndl);

    vec3 lit = vColor * (uAmbient + ndl * uLightColor) + uSpecularColor * spec;
    FragColor = vec4(lit, 1.0);
}
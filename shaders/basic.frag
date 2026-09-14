#version 330 core

in vec3 vColor;
in vec3 vNormal;

uniform vec3  uLightDir;      // world-space direction FROM surface TOWARD light (will be normalized)
uniform vec3  uLightColor;    // light color multiplier
uniform float uAmbient;       // ambient floor

out vec4 FragColor;

void main()
{
    vec3 N = normalize(vNormal);
    vec3 L = normalize(uLightDir);
    float ndl = max(dot(N, L), 0.0);

    vec3 lit = vColor * (uAmbient + pow(ndl, 3.0) * uLightColor);  // tighter falloff
    FragColor = vec4(lit, 1.0);
}
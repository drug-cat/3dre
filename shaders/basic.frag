#version 330 core

in vec3 vColor;
in vec3 vNormal;

uniform vec3  uLightDir;
uniform vec3  uLightColor;
uniform float uAmbient;

out vec4 FragColor;

void main()
{
    vec3 N = normalize(vNormal);
    vec3 L = normalize(uLightDir);
    float ndl = max(dot(N, L), 0.0);

    // DEBUG: show lighting as pure grayscale
    FragColor = vec4(vec3(ndl), 1.0);
}
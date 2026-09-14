#version 330 core

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aColor;
layout(location = 2) in vec3 aNormal;

uniform mat4 uMVP;
uniform mat4 uModel;

out vec3 vColor;
out vec3 vNormal;
out vec3 vWorldPos;

void main()
{
    vec4 world = uModel * vec4(aPos, 1.0);

    gl_Position = uMVP * vec4(aPos, 1.0);
    vColor    = aColor;
    vNormal   = mat3(uModel) * aNormal;   // valid for rotation-only models
    vWorldPos = world.xyz;
}
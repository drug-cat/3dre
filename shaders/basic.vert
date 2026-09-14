#version 330 core

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aColor;
layout(location = 2) in vec3 aNormal;

uniform mat4 uMVP;
uniform mat4 uModel;

out vec3 vColor;
out vec3 vNormal;

void main()
{
    gl_Position = uMVP * vec4(aPos, 1.0);
    vColor  = aColor;
    // No scale in our transforms → upper-left 3x3 of uModel is a valid normal transform
    vNormal = mat3(uModel) * aNormal;
}